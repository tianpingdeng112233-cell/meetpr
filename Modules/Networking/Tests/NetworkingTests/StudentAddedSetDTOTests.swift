import CoreModels
import Foundation
import Networking
import Testing

@Test func studentAddedResponseKeepsNullablePlanSlotAndOptionalDay() throws {
  let json = """
    {"logs":[{"id":"00000000-0000-4000-8000-000000000101",
    "student_id":"00000000-0000-4000-8000-000000000102",
    "exercise_id":"00000000-0000-4000-8000-000000000103",
    "plan_exercise_id":null,"adhoc":true,"set_index":0,"weight_kg":"50",
    "reps":5,"completed":true,"logged_at":"2026-10-14T10:00:00Z"}]}
    """
  let result = try MeetPRCodec.decoder.decode(AllStudentSetLogsDTO.self, from: Data(json.utf8))
  #expect(result.planned.isEmpty)
  #expect(result.added.count == 1)
  #expect(result.added.first?.planDayID == nil)
}

@Test func studentAddedRequestUsesDayAndAllScopeWithoutChangingPlanDefault() async throws {
  let dayID = UUID()
  let log = StudentAddedSetLog(
    id: UUID(), studentID: UUID(), planDayID: dayID, exerciseID: UUID(), setIndex: 0,
    loggedAt: Date(), loggedDate: "2026-10-14", weightKg: 55, reps: 5, completed: true)
  let body = try #require(
    JSONSerialization.jsonObject(
      with: MeetPRCodec.encoder.encode(CreateStudentAddedSetRequestDTO(log: log))) as? [String: Any]
  )
  #expect(body["plan_day_id"] as? String == dayID.uuidString)
  #expect(body["plan_exercise_id"] == nil)
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    #expect(request.url?.query?.contains("scope=all") == true)
    return APIResponse(data: Data("{\"logs\":[]}".utf8), statusCode: 200)
  }
  _ = try await api.allStudentSetLogs(
    studentID: log.studentID, from: "2026-10-01",
    endDate: "2026-10-15", accessToken: "test")
}

@Test(arguments: [
  "SETS_PLAN_DAY_NOT_PUBLISHED", "SETS_ADHOC_DAY_CONFLICT",
  "SET_NOT_STUDENT_ADDED", "SET_HAS_ATTACHMENT", "SET_HAS_COACH_FEEDBACK", "SET_NOT_FOUND",
])
func studentAddedErrorCodesSurviveTransport(code: String) async throws {
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(
      data: Data("{\"error\":\"\(code)\"}".utf8),
      statusCode: code == "SET_NOT_FOUND" ? 404 : code == "SETS_PLAN_DAY_NOT_PUBLISHED" ? 400 : 409)
  }
  do {
    try await api.deleteStudentAddedSet(id: UUID(), accessToken: "test")
    #expect(code == "SET_NOT_FOUND")
  } catch {
    #expect(BackendErrorEnvelope.machineCode(from: error) == code)
  }
}

@Test func plannedDTOAcceptsMissingPlanDayID() throws {
  let json = """
    {"id":"00000000-0000-4000-8000-000000000101",
    "student_id":"00000000-0000-4000-8000-000000000102",
    "plan_exercise_id":"00000000-0000-4000-8000-000000000103",
    "set_index":0,"weight_kg":"50","reps":5,"completed":true,
    "logged_at":"2026-10-14T10:00:00Z"}
    """
  let dto = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
  #expect(dto.planDayID == nil)
}
