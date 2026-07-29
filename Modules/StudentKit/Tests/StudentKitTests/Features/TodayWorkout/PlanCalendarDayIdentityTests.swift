import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func todayWorkoutLoadsPlanOnItsShanghaiCalendarDay() async throws {
  let utcCalendar = try calendar(timeZoneIdentifier: "UTC")
  let shanghaiCalendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
  let planDate = try date(2026, 7, 24, calendar: utcCalendar)
  let selectedDate = try date(2026, 7, 24, calendar: shanghaiCalendar)
  let plan = plan(on: planDate)
  let fixture = try await backendFixture(plan: plan, calendar: shanghaiCalendar)
  defer { try? FileManager.default.removeItem(at: fixture.cacheDirectory) }
  let viewModel = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(),
    calendar: shanghaiCalendar
  )

  await viewModel.load(date: selectedDate, studentID: StudentDemoSeed.studentID)

  guard case .loaded(let loadedDay, _) = viewModel.state else {
    Issue.record("Expected the July 24 workout to load, got \(viewModel.state)")
    return
  }
  #expect(loadedDay.id == plan.days[0].id)
}

@MainActor
@Test func todayWorkoutDoesNotLeakIntoNextShanghaiCalendarDay() async throws {
  let utcCalendar = try calendar(timeZoneIdentifier: "UTC")
  let shanghaiCalendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
  let planDate = try date(2026, 7, 24, calendar: utcCalendar)
  let selectedDate = try date(2026, 7, 25, calendar: shanghaiCalendar)
  let fixture = try await backendFixture(
    plan: plan(on: planDate),
    calendar: shanghaiCalendar
  )
  defer { try? FileManager.default.removeItem(at: fixture.cacheDirectory) }
  let viewModel = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(),
    calendar: shanghaiCalendar
  )

  await viewModel.load(date: selectedDate, studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .rest)
}

@Test func shanghaiEarlyMorningUsesTheSelectedCalendarDay() throws {
  let utcCalendar = try calendar(timeZoneIdentifier: "UTC")
  let shanghaiCalendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
  let july24PlanDate = try date(2026, 7, 24, calendar: utcCalendar)
  let july25PlanDate = try date(2026, 7, 25, calendar: utcCalendar)
  let earlyMorningDates = [
    try date(2026, 7, 25, hour: 0, minute: 0, calendar: shanghaiCalendar),
    try date(2026, 7, 25, hour: 7, minute: 59, calendar: shanghaiCalendar),
  ]

  for selectedDate in earlyMorningDates {
    #expect(
      !PlanCalendarDayIdentity.matches(
        planDate: july24PlanDate,
        selectedDate: selectedDate,
        selectedCalendar: shanghaiCalendar
      ))
    #expect(
      PlanCalendarDayIdentity.matches(
        planDate: july25PlanDate,
        selectedDate: selectedDate,
        selectedCalendar: shanghaiCalendar
      ))
  }
}

@Test func selectedTodayUsesDeviceDayInsteadOfGymDayCutoff() throws {
  let shanghaiCalendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
  let earlyMorning = try date(
    2026,
    7,
    29,
    hour: 2,
    minute: 30,
    calendar: shanghaiCalendar
  )
  let selectedToday = PlanCalendarDayIdentity.deviceDay(
    containing: earlyMorning,
    calendar: shanghaiCalendar
  )
  let gymDay = WorkoutDatePolicy.gymDayToday(now: earlyMorning)

  #expect(shanghaiCalendar.component(.day, from: selectedToday) == 29)
  #expect(shanghaiCalendar.component(.day, from: gymDay) == 28)
}

@Test func utcCalendarDayBehaviorRemainsUnchanged() throws {
  let utcCalendar = try calendar(timeZoneIdentifier: "UTC")
  let july24PlanDate = try date(2026, 7, 24, calendar: utcCalendar)
  let july24Selection = try date(
    2026,
    7,
    24,
    hour: 23,
    minute: 59,
    calendar: utcCalendar
  )
  let july25Selection = try date(2026, 7, 25, calendar: utcCalendar)

  #expect(
    PlanCalendarDayIdentity.matches(
      planDate: july24PlanDate,
      selectedDate: july24Selection,
      selectedCalendar: utcCalendar
    ))
  #expect(
    !PlanCalendarDayIdentity.matches(
      planDate: july24PlanDate,
      selectedDate: july25Selection,
      selectedCalendar: utcCalendar
    ))
}

@MainActor
@Test func todayWorkoutWeekIndexUsesTheSelectedShanghaiCalendarDay() async throws {
  let utcCalendar = try calendar(timeZoneIdentifier: "UTC")
  let shanghaiCalendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
  let planDate = try date(2026, 7, 24, calendar: utcCalendar)
  let selectedDate = try date(2026, 7, 31, calendar: shanghaiCalendar)
  let fixture = try await backendFixture(
    plan: plan(on: planDate),
    calendar: shanghaiCalendar
  )
  defer { try? FileManager.default.removeItem(at: fixture.cacheDirectory) }
  let viewModel = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(),
    calendar: shanghaiCalendar
  )

  await viewModel.load(date: selectedDate, studentID: StudentDemoSeed.studentID)

  #expect(viewModel.planContext?.weekIndex == 2)
}

@Test func repositoryWeekIndexCrossesWeeksOnTheShanghaiCalendarDay() async throws {
  let utcCalendar = try calendar(timeZoneIdentifier: "UTC")
  let shanghaiCalendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
  let startDate = try date(2026, 7, 18, calendar: utcCalendar)
  // Shanghai 7/25 00:30 is still 7/24 in UTC; a UTC reading would stay in week 1.
  let now = try date(2026, 7, 25, hour: 0, minute: 30, calendar: shanghaiCalendar)
  let fixture = try await backendFixture(
    plan: plan(on: startDate),
    calendar: shanghaiCalendar,
    now: { now }
  )
  defer { try? FileManager.default.removeItem(at: fixture.cacheDirectory) }
  let trainingPlan = TrainingPlan(
    id: UUID(),
    traineeID: StudentDemoSeed.studentID,
    name: "Cycle",
    startDate: startDate,
    endDate: try date(2026, 8, 14, calendar: utcCalendar),
    planWeeks: 4,
    source: .coach,
    status: .published,
    createdAt: startDate,
    updatedAt: startDate
  )

  #expect(await fixture.repository.currentWeekIndex(for: trainingPlan) == 2)
}

private struct BackendFixture {
  let repository: BackendStudentPlanRepository
  let cacheDirectory: URL
}

private func backendFixture(
  plan: StudentPlanView,
  calendar: Calendar,
  now: @escaping @Sendable () -> Date = { Date() }
) async throws -> BackendFixture {
  let cacheDirectory = FileManager.default.temporaryDirectory.appending(
    path: "PlanCalendarDayIdentityTests-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let cache = StudentPlanCache(directory: cacheDirectory)
  try await cache.save(plan: plan, studentID: StudentDemoSeed.studentID)
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: Data(), statusCode: 500)
  }
  return BackendFixture(
    repository: BackendStudentPlanRepository(
      api: api,
      session: PlanCalendarDayTestSession(),
      cache: cache,
      calendar: calendar,
      now: now
    ),
    cacheDirectory: cacheDirectory
  )
}

private func plan(on date: Date) -> StudentPlanView {
  let seed = StudentDemoSeed.makePlanView(today: date)
  let day = StudentPlanDay(
    id: seed.days[0].id,
    date: date,
    exercises: []
  )
  return StudentPlanView(
    cycleID: seed.cycleID,
    weekIndex: 1,
    startDate: date,
    endDate: date,
    days: [day]
  )
}

private func calendar(timeZoneIdentifier: String) throws -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
  return calendar
}

private func date(
  _ year: Int,
  _ month: Int,
  _ day: Int,
  hour: Int = 0,
  minute: Int = 0,
  calendar: Calendar
) throws -> Date {
  try #require(
    calendar.date(
      from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
      )))
}

private struct PlanCalendarDayTestSession: SessionStateReader {
  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}
