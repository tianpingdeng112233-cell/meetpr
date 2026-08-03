import Foundation
import Testing

@testable import CoreModels

@Test func parsesAllSupportedPushRoutes() throws {
  let conversationID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
  let studentID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
  let videoID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
  let requestID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000004"))
  let planID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000005"))

  let cases: [(PushPayloadValues, PushRouteIntent)] = [
    (
      PushPayloadValues(kind: "chat_message", conversationID: conversationID.uuidString),
      .chatMessage(conversationID: conversationID)
    ),
    (
      PushPayloadValues(kind: "missed_training", studentID: studentID.uuidString),
      .missedTraining(studentID: studentID)
    ),
    (
      PushPayloadValues(kind: "pr_congrats", studentID: studentID.uuidString),
      .prCongrats(studentID: studentID)
    ),
    (
      PushPayloadValues(
        kind: "video_pending",
        studentID: studentID.uuidString,
        videoID: videoID.uuidString
      ),
      .videoPending(studentID: studentID, videoID: videoID)
    ),
    (
      PushPayloadValues(kind: "bind_request", requestID: requestID.uuidString),
      .bindRequest(requestID: requestID)
    ),
    (
      PushPayloadValues(
        kind: "plan_shift",
        studentID: studentID.uuidString,
        planID: planID.uuidString
      ),
      .planShift(studentID: studentID, planID: planID)
    ),
  ]

  for (payload, expected) in cases {
    #expect(PushPayloadParser.route(from: payload) == expected)
  }
}

@Test func rejectsUnknownKindsAndMalformedRequiredIdentifiers() {
  let invalidPayloads = [
    PushPayloadValues(kind: nil),
    PushPayloadValues(kind: "admin_command"),
    PushPayloadValues(kind: "chat_message", conversationID: "not-a-uuid"),
    PushPayloadValues(kind: "missed_training"),
    PushPayloadValues(kind: "pr_congrats", studentID: ""),
    PushPayloadValues(kind: "video_pending", studentID: UUID().uuidString),
    PushPayloadValues(kind: "bind_request", requestID: "invalid"),
    PushPayloadValues(kind: "plan_shift", studentID: UUID().uuidString),
  ]

  for payload in invalidPayloads {
    #expect(PushPayloadParser.route(from: payload) == nil)
  }
}

@Test func foregroundPolicySuppressesOnlyChatMessages() {
  #expect(PushForegroundPresentation.policy(for: "chat_message") == .suppress)
  #expect(PushForegroundPresentation.policy(for: "video_pending") == .bannerAndSound)
  #expect(PushForegroundPresentation.policy(for: "unknown") == .bannerAndSound)
  #expect(PushForegroundPresentation.policy(for: nil) == .bannerAndSound)
}
