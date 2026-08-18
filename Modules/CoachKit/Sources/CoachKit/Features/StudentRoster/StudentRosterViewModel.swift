import CoreModels
import Foundation
import Observation
import RepositoryContracts

struct StudentRosterRowModel: Hashable, Identifiable, Sendable {
  let student: CoachStudentSummary
  let lastActiveAt: Date?
  let triageSignals: [TriageSignal]
  let trainingDays: [CoachWeekOverview.TrainingDay]

  init(
    student: CoachStudentSummary,
    lastActiveAt: Date?,
    triageSignals: [TriageSignal],
    trainingDays: [CoachWeekOverview.TrainingDay] = []
  ) {
    self.student = student
    self.lastActiveAt = lastActiveAt
    self.triageSignals = triageSignals
    self.trainingDays = trainingDays
  }

  var id: UUID { student.id }

  var needsAttention: Bool {
    !triageSignals.isEmpty
  }

  var statusText: String {
    CoachStudentFormatting.statusText(student.status)
  }
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class StudentRosterViewModel {
  enum LoadState: Equatable, Sendable {
    var isFailure: Bool {
      if case .failed = self { return true }
      return false
    }

    case idle
    case loading
    case loaded
    case failed(String)
  }

  var state: LoadState = .idle
  var rows: [StudentRosterRowModel] = []
  var searchText = ""

  var pendingAttentionCount: Int {
    triageRows.count
  }

  var triageRows: [StudentRosterRowModel] {
    rows.filter(\.needsAttention)
  }

  var filteredRows: [StudentRosterRowModel] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return rows }
    return rows.filter {
      $0.student.displayName.localizedCaseInsensitiveContains(query)
    }
  }

  @ObservationIgnored private let students: any PlanRepository
  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let trainingLogs: any StudentTrainingLogRepository
  @ObservationIgnored private let feedback: any StudentFeedbackRepository
  @ObservationIgnored private let now: @Sendable () -> Date

  init(
    students: any PlanRepository,
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.students = students
    self.plans = plans
    self.trainingLogs = trainingLogs
    self.feedback = feedback
    self.now = now
  }

  func loadIfNeeded() async {
    // Both CoachRootView and StudentRosterView call this on appear; loading
    // must not stack a second full refresh (Codex P2).
    guard state == .idle || state.isFailure else { return }
    await refresh()
  }

  /// Evaluation completed from the detail page (Codex review P1): flip the
  /// row to active in place — a full refresh would flash `.loading` over the
  /// whole roster for a one-field change. The next pull-to-refresh converges
  /// with the server anyway.
  func markStudentActive(_ studentID: UUID) {
    rows = rows.map { row in
      guard row.student.id == studentID else { return row }
      return StudentRosterRowModel(
        student: CoachStudentSummary(
          id: row.student.id,
          displayName: row.student.displayName,
          status: .active
        ),
        lastActiveAt: row.lastActiveAt,
        triageSignals: row.triageSignals,
        trainingDays: row.trainingDays
      )
    }
  }

  func refresh() async {
    state = .loading
    do {
      let summaries = try await students.fetchStudents()
      rows = await loadRows(for: summaries)
      state = .loaded
    } catch {
      rows = []
      state = .failed(CoachLocalization.localized("coach.roster.error.load"))
    }
  }

  /// Per-student fetches fan out concurrently (029 follow-up: the first pass
  /// pulled plan/logs/feedback serially per row, so the roster's first paint
  /// degraded linearly with student count). Results keep the summaries' order.
  private func loadRows(for summaries: [CoachStudentSummary]) async -> [StudentRosterRowModel] {
    let plans = self.plans
    let trainingLogs = self.trainingLogs
    let feedback = self.feedback
    let now = self.now
    // Sliding window of 4: still concurrent, but a big roster can't hammer
    // the plan/log/feedback endpoints with 3N simultaneous calls (Codex P2;
    // an aggregated roster-summary endpoint is the post-V0.1 fix, FOLLOWUPS).
    let maxConcurrent = 4
    return await withTaskGroup(of: (Int, StudentRosterRowModel).self) { group in
      var iterator = summaries.enumerated().makeIterator()
      func submitNext() {
        guard let (index, summary) = iterator.next() else { return }
        group.addTask {
          let row = await Self.loadRow(
            for: summary,
            plans: plans,
            trainingLogs: trainingLogs,
            feedback: feedback,
            now: now
          )
          return (index, row)
        }
      }
      for _ in 0..<maxConcurrent { submitNext() }
      var ordered = [StudentRosterRowModel?](repeating: nil, count: summaries.count)
      for await (index, row) in group {
        ordered[index] = row
        submitNext()
      }
      return ordered.compactMap { $0 }
    }
  }

  /// 计划日与完成日志配对的时间窗:±36h 覆盖任何时区/DST 偏移,
  /// 又不至于把整份日志挂到每一个训练日上。
  private static let logPairingWindow: TimeInterval = 36 * 60 * 60

  private static func loadRow(
    for summary: CoachStudentSummary,
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    now: @Sendable () -> Date
  ) async -> StudentRosterRowModel {
    do {
      let timestamp = now()
      let plan = try await plans.fetchCurrentPlan(studentID: summary.id)
      let range = Self.logFetchRange(for: plan, now: timestamp)
      async let logs = trainingLogs.fetchLogs(studentID: summary.id, in: range)
      async let feedbackItems = feedback.fetchInbox(studentID: summary.id)
      return Self.makeRow(
        summary: summary,
        plan: plan,
        logs: try await logs,
        feedback: try await feedbackItems,
        now: timestamp
      )
    } catch {
      return StudentRosterRowModel(
        student: summary,
        lastActiveAt: nil,
        triageSignals: [],
        trainingDays: []
      )
    }
  }

  static func makeRow(
    summary: CoachStudentSummary,
    plan: StudentPlanView?,
    logs: [StudentSetLog],
    feedback: [CoachFeedback],
    now: Date
  ) -> StudentRosterRowModel {
    let plannedDays = plan?.days.filter { !$0.exercises.isEmpty } ?? []
    // 完成态不在这里固化:只把「可能与这一天配对」的完成日志时间戳带下去,
    // 由 CoachWeekOverview 聚合时用同一份 calendar 现场判定(见 TrainingDay 注释)。
    // ±36h 足够覆盖任何时区/DST 偏移,又不会把整份日志挂到每一天上。
    let completedLogDates = logs.filter(\.completed).map(\.loggedAt)
    let trainingDays = plannedDays.map { day in
      CoachWeekOverview.TrainingDay(
        date: day.date,
        completedLogDates: completedLogDates.filter {
          abs($0.timeIntervalSince(day.date)) <= Self.logPairingWindow
        }
      )
    }
    let latestLog = logs.filter(\.completed).map(\.loggedAt).max()
    let triageSignals = StudentTriageSignalCalculator.signals(
      studentID: summary.id,
      plan: plan,
      logs: logs,
      feedback: feedback,
      now: now
    )

    return StudentRosterRowModel(
      student: summary,
      lastActiveAt: latestLog,
      triageSignals: triageSignals,
      trainingDays: trainingDays
    )
  }

  private static func logFetchRange(for plan: StudentPlanView?, now: Date) -> ClosedRange<Date> {
    let calendar = CoachFeatureCalendar.calendar
    let today = CoachFeatureCalendar.startOfDay(now, calendar: calendar)
    let lookbackStart =
      calendar.date(
        byAdding: .day,
        value: -StudentTriageSignalCalculator.notTrainedLookbackDays,
        to: today
      ) ?? today
    let planStart = plan.map { CoachFeatureCalendar.startOfDay($0.startDate, calendar: calendar) }
    let start = min(planStart ?? lookbackStart, lookbackStart)
    let end = CoachFeatureCalendar.endOfDay(now, calendar: calendar)
    return start...max(start, end)
  }
}
