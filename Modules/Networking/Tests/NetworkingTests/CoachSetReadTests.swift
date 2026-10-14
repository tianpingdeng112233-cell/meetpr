import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func coachReadRequestsAllLogs() async throws {
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    let url = try #require(request.url)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.queryItems?.contains(URLQueryItem(name: "scope", value: "all")) == true)
    return APIResponse(data: Data(#"{"logs":[]}"#.utf8), statusCode: 200)
  }
  _ = try await client.coachSetLogs(
    studentID: UUID(), from: Date(), endDate: Date(), accessToken: "test")
}

@Test func plannedLogDecodesOptionalDayOwnership() throws {
  let id = UUID()
  let json = """
    {"id":"\(id)","student_id":"\(id)","plan_exercise_id":"\(id)",
    "set_index":0,"weight_kg":"100","reps":3,"completed":true,
    "logged_at":"2026-10-14T12:00:00Z"}
    """
  let legacy = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(json.utf8))
  #expect(legacy.planDayID == nil)
  let owned = json.replacing("\"set_index\"", with: "\"plan_day_id\":\"\(id)\",\"set_index\"")
  let decoded = try MeetPRCodec.decoder.decode(SetLogDTO.self, from: Data(owned.utf8))
  #expect(decoded.planDayID == id)
}

@Test func coachReadDecodesUnplannedAndLegacyLogs() throws {
  let id = UUID()
  let json = """
    {"logs":[{"id":"\(id)","student_id":"\(id)","plan_exercise_id":null,
    "plan_day_id":"\(id)","exercise_id":"\(id)","adhoc":true,
    "set_index":1,"weight_kg":"12.5","reps":12,"completed":true,
    "logged_at":"2026-10-14T12:00:00Z"}]}
    """
  let result = try MeetPRCodec.decoder.decode(CoachSetLogsResponseDTO.self, from: Data(json.utf8))
  let log = try #require(result.logs.first)
  #expect(log.planExerciseID == nil)
  #expect(log.planDayID == id)
  #expect(log.adhoc)
  #expect(log.weightKg == 12.5)
  let legacy = json.replacing("\"plan_day_id\":\"\(id)\",", with: "")
    .replacing("\"adhoc\":true,", with: "")
  let oldResult = try MeetPRCodec.decoder.decode(
    CoachSetLogsResponseDTO.self, from: Data(legacy.utf8))
  #expect(oldResult.logs.first?.planDayID == nil)
  #expect(oldResult.logs.first?.adhoc == false)
}
