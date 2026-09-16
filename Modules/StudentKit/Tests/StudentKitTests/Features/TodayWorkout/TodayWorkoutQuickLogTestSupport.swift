import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

let quickLogNow = Date(timeIntervalSince1970: 1_768_262_400)

// Shared fixtures and doubles for the quick-log (spec 081) view-model seam.

@MainActor
func makeQuickLogFixture(
  logs: any StudentTrainingLogRepository,
  e1rm: InMemoryE1RMRepository = InMemoryE1RMRepository(),
  dayOffset: Int = 2
) async throws -> QuickLogFixture {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView(today: quickLogNow, todayOffset: 2)
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store, now: { quickLogNow }),
    logs: logs,
    e1rm: e1rm,
    now: { quickLogNow }
  )
  await viewModel.load(dayID: plan.days[dayOffset].id, studentID: studentID)
  guard case .loaded(let day, let drafts) = viewModel.state else {
    throw QuickLogTestFailure("expected loaded state")
  }
  return QuickLogFixture(
    viewModel: viewModel,
    studentID: studentID,
    day: day,
    drafts: drafts,
    store: store
  )
}

func makeQuickLogTestPlan(
  drafts: [TodayWorkoutViewModel.SetRowDraft],
  selectedDate: Date = quickLogNow
) -> QuickLogPlan {
  QuickLogPlan(
    drafts: drafts,
    selectedDate: selectedDate,
    allowedDateRange: quickLogNow.addingTimeInterval(-7 * 86_400)...quickLogNow,
    calendar: quickLogUTCCalendar
  )
}

var quickLogUTCCalendar: Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
  return calendar
}

func quickLogLocalNoon(for date: Date) -> Date {
  let components = quickLogUTCCalendar.dateComponents([.year, .month, .day], from: date)
  return quickLogUTCCalendar.date(
    from: DateComponents(
      year: components.year,
      month: components.month,
      day: components.day,
      hour: 12
    )
  ) ?? .distantPast
}

@MainActor
struct QuickLogFixture {
  let viewModel: TodayWorkoutViewModel
  let studentID: UUID
  let day: StudentPlanDay
  let drafts: [TodayWorkoutViewModel.SetRowDraft]
  let store: TestStudentPlanStore
}

struct QuickLogTestFailure: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

actor FailOnceTrainingLogRepository: StudentTrainingLogRepository {
  private let failingAttempt: Int
  private var hasFailed = false
  private var logs: [StudentSetLog] = []
  private var attempts: [(UUID, Int)] = []

  init(failingAttempt: Int) {
    self.failingAttempt = failingAttempt
  }

  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    attempts.append((log.planExerciseID, log.setIndex))
    if attempts.count == failingAttempt, !hasFailed {
      hasFailed = true
      throw QuickLogTestFailure("planned record failure")
    }
    logs.removeAll {
      $0.planExerciseID == log.planExerciseID && $0.setIndex == log.setIndex
    }
    logs.append(log)
    return log
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    logs.filter { $0.studentID == studentID && dateRange.contains($0.loggedAt) }
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    logs.filter { $0.studentID == studentID && $0.planExerciseID == planExerciseID }
  }

  func storedLogs() -> [StudentSetLog] {
    logs
  }

  func attemptedSlots() -> [(UUID, Int)] {
    attempts
  }
}

actor CompletionFailingPlanRepository: StudentPlanRepository {
  private let plan: StudentPlanView
  private var completionCalls = 0

  init(plan: StudentPlanView) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    plan
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    plan.days
  }

  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    completionCalls += 1
    throw PlanDayCompletionError.planNotActive
  }

  func completionCallCount() -> Int {
    completionCalls
  }
}

/// Runs a hook after every successful write — used to simulate a day switch
/// racing a quick-log submission.
actor HookedTrainingLogRepository: StudentTrainingLogRepository {
  private var logs: [StudentSetLog] = []
  private var onRecord: (@Sendable () async -> Void)?

  func setOnRecord(_ hook: @escaping @Sendable () async -> Void) {
    onRecord = hook
  }

  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    logs.removeAll { $0.planExerciseID == log.planExerciseID && $0.setIndex == log.setIndex }
    logs.append(log)
    if let onRecord {
      self.onRecord = nil
      await onRecord()
    }
    return log
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    logs.filter { $0.studentID == studentID && dateRange.contains($0.loggedAt) }
  }

  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) async throws -> [StudentSetLog] {
    logs.filter { $0.studentID == studentID && $0.planExerciseID == planExerciseID }
  }
}
