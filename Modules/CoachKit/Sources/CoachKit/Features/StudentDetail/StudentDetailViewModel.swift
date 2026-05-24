import CoreModels
import Foundation
import Observation
import RepositoryContracts

enum StudentDetailSection: String, CaseIterable, Identifiable, Sendable {
  case overview
  case execution
  case videos
  case growth
  case feedback

  var id: String { rawValue }

  var title: String {
    switch self {
    case .overview: "概览"
    case .execution: "执行"
    case .videos: "视频"
    case .growth: "成长"
    case .feedback: "反馈"
    }
  }
}

struct StudentExecutionDay: Hashable, Identifiable, Sendable {
  let date: Date
  let planDay: StudentPlanDay?
  let logs: [StudentSetLog]

  var id: Date { date }

  var isRestDay: Bool {
    (planDay?.exercises.isEmpty ?? true) && logs.isEmpty
  }

  var plannedSetCount: Int {
    planDay?.exercises.reduce(0) { count, exercise in
      count + exercise.prescribedSets.count
    } ?? 0
  }

  var completedSetCount: Int {
    logs.filter(\.completed).count
  }

  var completionText: String {
    guard plannedSetCount > 0 else {
      return logs.isEmpty ? "休息日" : "\(completedSetCount) 组已记录"
    }
    return "\(completedSetCount)/\(plannedSetCount) 组"
  }
}

struct StudentOverviewSummary: Equatable, Sendable {
  let completedTrainingDays: Int
  let plannedTrainingDays: Int
  let latestFeedback: CoachFeedback?
  let latestActivityAt: Date?

  static let empty = StudentOverviewSummary(
    completedTrainingDays: 0,
    plannedTrainingDays: 0,
    latestFeedback: nil,
    latestActivityAt: nil
  )
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class StudentDetailViewModel {
  enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  let summary: CoachStudentSummary
  var selectedSection: StudentDetailSection = .overview
  var state: LoadState = .idle
  private(set) var plan: StudentPlanView?
  private(set) var executionDays: [StudentExecutionDay] = []
  private(set) var feedbackItems: [CoachFeedback] = []
  private(set) var overview = StudentOverviewSummary.empty

  var plannedDays: [StudentPlanDay] {
    plan?.days ?? []
  }

  var allPlanExercises: [StudentPlanExercise] {
    plannedDays.flatMap(\.exercises)
  }

  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let trainingLogs: any StudentTrainingLogRepository
  @ObservationIgnored private let feedback: any StudentFeedbackRepository
  @ObservationIgnored private let now: @Sendable () -> Date

  init(
    summary: CoachStudentSummary,
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.summary = summary
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
      let loadedPlan = try await plans.fetchCurrentPlan(studentID: summary.id)
      let range = Self.weekRange(for: loadedPlan, now: now())
      let loadedLogs = try await trainingLogs.fetchLogs(studentID: summary.id, in: range)
      let loadedFeedback = try await feedback.fetchInbox(studentID: summary.id)

      plan = loadedPlan
      executionDays = Self.makeExecutionDays(plan: loadedPlan, logs: loadedLogs, now: now())
      feedbackItems = loadedFeedback.sorted { $0.postedAt > $1.postedAt }
      overview = Self.makeOverview(days: executionDays, feedback: feedbackItems)
      state = .loaded
    } catch {
      state = .failed("学员详情加载失败，请稍后重试")
    }
  }

  func select(_ section: StudentDetailSection) {
    selectedSection = section
  }

  func appendPostedFeedback(_ item: CoachFeedback) {
    feedbackItems.removeAll { $0.id == item.id }
    feedbackItems.insert(item, at: 0)
    feedbackItems.sort { $0.postedAt > $1.postedAt }
    overview = Self.makeOverview(days: executionDays, feedback: feedbackItems)
  }

  static func makeExecutionDays(
    plan: StudentPlanView?,
    logs: [StudentSetLog],
    now: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> [StudentExecutionDay] {
    let startDate =
      plan?.startDate
      ?? (calendar.date(
        byAdding: .day,
        value: -6,
        to: now
      ) ?? now)
    let daysByStart = Dictionary(
      uniqueKeysWithValues: (plan?.days ?? []).map {
        (CoachFeatureCalendar.startOfDay($0.date, calendar: calendar), $0)
      }
    )

    return (0..<7).map { offset in
      let date =
        calendar.date(byAdding: .day, value: offset, to: startDate)
        ?? startDate
      let dayStart = CoachFeatureCalendar.startOfDay(date, calendar: calendar)
      let dayLogs =
        logs
        .filter { CoachFeatureCalendar.isSameDay($0.loggedAt, date, calendar: calendar) }
        .sorted { lhs, rhs in
          if lhs.planExerciseID == rhs.planExerciseID {
            return lhs.setIndex < rhs.setIndex
          }
          return lhs.loggedAt < rhs.loggedAt
        }
      return StudentExecutionDay(
        date: dayStart,
        planDay: daysByStart[dayStart],
        logs: dayLogs
      )
    }
  }

  static func makeOverview(
    days: [StudentExecutionDay],
    feedback: [CoachFeedback]
  ) -> StudentOverviewSummary {
    let plannedDays = days.filter { ($0.planDay?.exercises.isEmpty == false) }
    let completedDays = plannedDays.filter { $0.completedSetCount > 0 }
    return StudentOverviewSummary(
      completedTrainingDays: completedDays.count,
      plannedTrainingDays: plannedDays.count,
      latestFeedback: feedback.sorted { $0.postedAt > $1.postedAt }.first,
      latestActivityAt: days.flatMap(\.logs).map(\.loggedAt).max()
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
