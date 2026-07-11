import CoreModels
import Foundation
import Networking
import RepositoryContracts
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

@Test func inMemoryStudentPlanRepositoryShiftsAndCancelsOneDay() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let original = try #require(plan.days.first)
  let target = original.date.addingTimeInterval(2 * 86_400)
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan])
  )

  try await repository.shiftDay(id: original.id, to: target, studentID: studentID)
  let shifted = try #require(
    try await repository.fetchCurrentPlan(studentID: studentID)?.days.first { $0.id == original.id }
  )
  #expect(shifted.scheduledDate == original.date)
  #expect(shifted.shiftedToDate == target)
  #expect(shifted.date == target)

  try await repository.cancelShift(dayID: original.id, studentID: studentID)
  let restored = try #require(
    try await repository.fetchCurrentPlan(studentID: studentID)?.days.first { $0.id == original.id }
  )
  #expect(restored.shiftedToDate == nil)
  #expect(restored.date == original.date)
}

@Test(arguments: [
  ("PLAN_NOT_ACTIVE", PlanDayShiftError.planNotActive),
  ("SHIFT_ONLY_TODAY", PlanDayShiftError.onlyToday),
  ("SHIFT_DAY_HAS_LOGS", PlanDayShiftError.dayHasLogs),
  ("SHIFT_TARGET_NOT_REST_DAY", PlanDayShiftError.targetNotRestDay),
])
func backendStudentPlanRepositoryMapsShiftMachineCodes(
  machineCode: String,
  expected: PlanDayShiftError
) async throws {
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(
      data: Data("{\"error\":\"\(machineCode)\"}".utf8),
      statusCode: 409
    )
  }
  let repository = BackendStudentPlanRepository(
    api: api,
    session: ShiftTestSession()
  )

  do {
    try await repository.shiftDay(id: UUID(), to: Date(), studentID: UUID())
    Issue.record("Expected \(machineCode) to throw")
  } catch let error as PlanDayShiftError {
    #expect(error == expected)
  } catch {
    Issue.record("Unexpected error: \(error)")
  }
}

private struct ShiftTestSession: SessionStateReader {
  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}
