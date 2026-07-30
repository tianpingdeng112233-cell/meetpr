import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func todayRefreshThrottleUsesVolatileRefreshWithoutRefetchingPlan() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let plans = CountingStudentPlanRepository(plan: plan)
  let viewModel = WeekOverviewViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: studentID)
  #expect(await plans.currentPlanFetchCount == 1)
  #expect(await plans.cycleDaysFetchCount == 0)

  let initialRefresh = Date(timeIntervalSince1970: 1_777_248_000)
  var throttle = StudentTodayRefreshThrottle(lastFullRefreshAt: initialRefresh)
  let refresh = throttle.refreshWhenReturning(
    at: initialRefresh.addingTimeInterval(StudentTodayRefreshThrottle.interval - 1)
  )

  #expect(refresh == .volatileOnly)
  if refresh == .volatileOnly {
    await viewModel.refreshLogs(studentID: studentID)
  }
  #expect(await plans.currentPlanFetchCount == 1)
  #expect(await plans.cycleDaysFetchCount == 0)
}

private actor CountingStudentPlanRepository: StudentPlanRepository {
  private let plan: StudentPlanView
  private(set) var currentPlanFetchCount = 0
  private(set) var cycleDaysFetchCount = 0

  init(plan: StudentPlanView) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    currentPlanFetchCount += 1
    return plan
  }

  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    plan.days.first {
      PlanCalendarDayIdentity.matches(
        planDate: $0.date,
        selectedDate: date,
        selectedCalendar: .current
      )
    }
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    cycleDaysFetchCount += 1
    return plan.days
  }
}
