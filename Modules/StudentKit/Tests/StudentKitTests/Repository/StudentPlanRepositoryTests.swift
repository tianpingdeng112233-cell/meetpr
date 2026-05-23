import Foundation
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
