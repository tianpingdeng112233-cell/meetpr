import CoreModels
import Foundation
import Observation
import RepositoryContracts

struct StudentRosterRowModel: Hashable, Identifiable, Sendable {
  let student: CoachStudentSummary
  let plannedTrainingDays: Int
  let completedTrainingDays: Int
  let lastActiveAt: Date?
  let triageSignals: [TriageSignal]
  let competitionCountdownText: String?
  let attendanceBarTones: [RosterAttendanceBarTone]?

  var id: UUID { student.id }

  var needsAttention: Bool {
    !triageSignals.isEmpty
  }

  var completionText: String {
    "本周完成 \(completedTrainingDays)/\(plannedTrainingDays) 训练"
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

  func applyRenamedStudent(_ renamed: CoachStudentSummary) {
    rows = rows.map { row in
      guard row.student.id == renamed.id else { return row }
      return StudentRosterRowModel(
        student: renamed,
        plannedTrainingDays: row.plannedTrainingDays,
        completedTrainingDays: row.completedTrainingDays,
        lastActiveAt: row.lastActiveAt,
        triageSignals: row.triageSignals,
        competitionCountdownText: CompetitionCountdownText.make(
          competitionDate: renamed.competitionDate,
          relativeTo: now()
        ),
        attendanceBarTones: renamed.recentFourWeeks?.map(RosterAttendanceBarTone.map)
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
      state = .failed("学员加载失败，请稍后重试")
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

  private static func loadRow(
    for summary: CoachStudentSummary,
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    now: @Sendable () -> Date
  ) async -> StudentRosterRowModel {
    let timestamp = now()
    do {
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
        plannedTrainingDays: 0,
        completedTrainingDays: 0,
        lastActiveAt: nil,
        triageSignals: [],
        competitionCountdownText: CompetitionCountdownText.make(
          competitionDate: summary.competitionDate,
          relativeTo: timestamp
        ),
        attendanceBarTones: summary.recentFourWeeks?.map(RosterAttendanceBarTone.map)
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
    let completedDays = plannedDays.filter { day in
      logs.contains { log in
        log.completed && CoachFeatureCalendar.isSameDay(log.loggedAt, day.date)
      }
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
      plannedTrainingDays: plannedDays.count,
      completedTrainingDays: completedDays.count,
      lastActiveAt: latestLog,
      triageSignals: triageSignals,
      competitionCountdownText: CompetitionCountdownText.make(
        competitionDate: summary.competitionDate,
        relativeTo: now
      ),
      attendanceBarTones: summary.recentFourWeeks?.map(RosterAttendanceBarTone.map)
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
