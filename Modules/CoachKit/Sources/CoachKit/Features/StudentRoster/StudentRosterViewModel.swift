import CoreModels
import Foundation
import Observation
import RepositoryContracts

struct StudentRosterRowModel: Hashable, Identifiable, Sendable {
  let student: CoachStudentSummary
  let plannedTrainingDays: Int
  let completedTrainingDays: Int
  let lastActiveAt: Date?
  let needsAttention: Bool

  var id: UUID { student.id }

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
    case idle
    case loading
    case loaded
    case failed(String)
  }

  var state: LoadState = .idle
  var rows: [StudentRosterRowModel] = []
  var searchText = ""

  var pendingAttentionCount: Int {
    rows.filter(\.needsAttention).count
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
    guard state != .loaded else { return }
    await refresh()
  }

  func refresh() async {
    state = .loading
    do {
      let summaries = try await students.fetchStudents()
      var loadedRows: [StudentRosterRowModel] = []
      for summary in summaries {
        loadedRows.append(await makeRow(for: summary))
      }
      rows = loadedRows
      state = .loaded
    } catch {
      rows = []
      state = .failed("学员加载失败，请稍后重试")
    }
  }

  private func makeRow(for summary: CoachStudentSummary) async -> StudentRosterRowModel {
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: summary.id)
      let range = Self.weekRange(for: plan, now: now())
      let logs = try await trainingLogs.fetchLogs(studentID: summary.id, in: range)
      let feedbackItems = try await feedback.fetchInbox(studentID: summary.id)
      return Self.makeRow(
        summary: summary,
        plan: plan,
        logs: logs,
        feedback: feedbackItems,
        now: now()
      )
    } catch {
      return StudentRosterRowModel(
        student: summary,
        plannedTrainingDays: 0,
        completedTrainingDays: 0,
        lastActiveAt: nil,
        needsAttention: false
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
    let latestFeedback = feedback.map(\.postedAt).max()
    let threeDaysAgo =
      CoachFeatureCalendar.calendar.date(byAdding: .day, value: -3, to: now) ?? now
    let hasRecentLog = latestLog.map { $0 >= threeDaysAgo && $0 <= now } ?? false
    let hasNewFeedback =
      latestLog.flatMap { logDate in latestFeedback.map { $0 >= logDate } } ?? false

    return StudentRosterRowModel(
      student: summary,
      plannedTrainingDays: plannedDays.count,
      completedTrainingDays: completedDays.count,
      lastActiveAt: latestLog,
      needsAttention: hasRecentLog && !hasNewFeedback
    )
  }

  private static func weekRange(for plan: StudentPlanView?, now: Date) -> ClosedRange<Date> {
    guard let plan else {
      let start = CoachFeatureCalendar.calendar.date(byAdding: .day, value: -6, to: now) ?? now
      return CoachFeatureCalendar.dateRange(starting: start, days: 7)
    }
    return CoachFeatureCalendar.dateRange(starting: plan.startDate, days: 7)
  }
}
