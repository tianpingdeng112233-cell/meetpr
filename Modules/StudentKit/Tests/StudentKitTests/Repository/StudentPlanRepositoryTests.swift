import Foundation
import Networking
import Testing

@testable import StudentKit

@Test func studentPlanRepositoryFetchesProjectionAndSlicesDay() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let repository = InMemoryStudentPlanRepository(store: store)

  let fetchedPlan = try await repository.fetchCurrentPlan(studentID: studentID)
  #expect(fetchedPlan == plan)

  let firstDay = try await repository.fetchDay(
    studentID: studentID,
    date: plan.days[0].date.addingTimeInterval(3_600)
  )
  #expect(firstDay == plan.days[0])

  let days = try await repository.fetchCycleDays(studentID: studentID)
  #expect(days == plan.days.sorted { $0.date < $1.date })
}

@Test func studentPlanRepositoryReturnsEmptyForMissingProjection() async throws {
  let repository = InMemoryStudentPlanRepository(store: TestStudentPlanStore())

  let studentID = UUID()
  #expect(try await repository.fetchCurrentPlan(studentID: studentID) == nil)
  #expect(try await repository.fetchDay(studentID: studentID, date: Date()) == nil)
  #expect(try await repository.fetchCycleDays(studentID: studentID).isEmpty)
}

@Test func backendStudentPlanSelectionPrefersPlanCoveringTodayOverLaterFuturePlan() throws {
  let today = date("2026-07-08")
  let active = plan(name: "当前计划", start: "2026-06-29", end: "2026-09-20", updated: "2026-07-08")
  let future = plan(name: "下个周期", start: "2026-10-01", end: "2026-12-23", updated: "2026-07-09")

  let selected = try #require(
    BackendStudentPlanRepository.selectCurrentPlan(
      from: [future, active],
      today: today
    )
  )

  #expect(selected.id == active.id)
}

@Test func backendStudentPlanSelectionFallsBackToNearestUpcomingPlan() throws {
  let today = date("2026-07-08")
  let nextWeek = plan(name: "下周计划", start: "2026-07-15", end: "2026-10-06", updated: "2026-07-08")
  let nextMonth = plan(name: "下月计划", start: "2026-08-01", end: "2026-10-23", updated: "2026-07-09")

  let selected = try #require(
    BackendStudentPlanRepository.selectCurrentPlan(
      from: [nextMonth, nextWeek],
      today: today
    )
  )

  #expect(selected.id == nextWeek.id)
}

@Test func backendStudentPlanSelectionFallsBackToLatestEndedPlan() throws {
  let today = date("2026-07-08")
  let older = plan(name: "旧计划", start: "2026-01-01", end: "2026-03-25", updated: "2026-03-25")
  let latest = plan(name: "刚结束计划", start: "2026-04-01", end: "2026-06-23", updated: "2026-06-23")

  let selected = try #require(
    BackendStudentPlanRepository.selectCurrentPlan(
      from: [older, latest],
      today: today
    )
  )

  #expect(selected.id == latest.id)
}

private func plan(name: String, start: String, end: String, updated: String) -> PlanDTO {
  PlanDTO(
    id: UUID(),
    coachID: UUID(),
    traineeID: UUID(),
    name: name,
    startDate: date(start),
    endDate: date(end),
    planWeeks: 12,
    source: .coach,
    status: .published,
    createdAt: date(start),
    updatedAt: date(updated)
  )
}

private func date(_ value: String) -> Date {
  var formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .gregorian)
  formatter.timeZone = TimeZone(identifier: "UTC")
  formatter.dateFormat = "yyyy-MM-dd"
  return formatter.date(from: value)!
}
