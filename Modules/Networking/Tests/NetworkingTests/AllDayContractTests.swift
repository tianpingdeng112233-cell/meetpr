import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func allDayBackend065SharedFixtureDecodesNullableLogAndExerciseNote() throws {
  let samples = try allDayContractSamples()
  let logs = try #require(samples["nullable_set_log"]?["response"] as? [String: Any])
  let rawLogs = try #require(logs["logs"] as? [[String: Any]])
  let log = try MeetPRCodec.decoder.decode(
    CoachSetLogDTO.self, from: JSONSerialization.data(withJSONObject: rawLogs[0]))
  #expect(log.weightKg == nil)
  #expect(log.rpe == 8)
  let response = try #require(samples["exercise_ref_message"]?["response"])
  let message = try MeetPRCodec.decoder.decode(
    ChatMessageResponseDTO.self, from: JSONSerialization.data(withJSONObject: response)
  ).message
  #expect(message.exerciseRef?.exerciseName == "暂停卧推")
  #expect(message.exerciseRef?.shortDate == "11/10")
  #expect(message.toDomain().exerciseRef == message.exerciseRef)
  #expect(message.setRef == nil)
  #expect(message.videoURL == nil)
  let rawSuggestions = try #require(samples["weight_suggestions"]?["response"] as? [String: Any])
  let suggestions = try MeetPRCodec.decoder.decode(
    [SetWeightSuggestionRecord].self,
    from: JSONSerialization.data(withJSONObject: try #require(rawSuggestions["suggestions"])))
  #expect(suggestions.first?.weightKg == 102.5)
}

@Test func allDayExerciseRequestPreservesCanonicalContractWithoutVideoOrSetRef() throws {
  let samples = try allDayContractSamples()
  let request = try #require(samples["exercise_ref_message"]?["request"] as? [String: Any])
  let body = try #require(request["body"] as? [String: Any])
  let dto = try MeetPRCodec.decoder.decode(
    ChatSendMessageRequestDTO.self, from: JSONSerialization.data(withJSONObject: body))
  let encoded = try #require(
    JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(dto)) as? [String: Any])
  #expect(encoded["body"] as? String == body["body"] as? String)
  #expect(encoded["exercise_ref"] != nil)
  #expect(encoded["video_id"] == nil)
  #expect(encoded["set_ref"] == nil)
}

private func allDayContractSamples() throws -> [String: [String: Any]] {
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
  let url = root.appending(path: "specs/107-all-day-sheet/contract-samples.json")
  return try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [String: Any]])
}

@Test func allDayRequestsAdvertiseNullableWeightCapability() async throws {
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    #expect(request.value(forHTTPHeaderField: "X-MeetPR-Caps") == "set-weight-nullable")
    return APIResponse(data: Data("{}".utf8), statusCode: 200)
  }
  _ = try await client.getResponse(path: "/plans", accessToken: "fixture-token")
  _ = try await client.post(.authLogin, body: Data("{}".utf8))
}
