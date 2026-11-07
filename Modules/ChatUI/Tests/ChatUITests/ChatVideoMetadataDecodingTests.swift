import CoreModels
import Foundation
import Networking
import Testing

@testable import ChatUI

@Suite struct ChatVideoMetadataDecodingTests {
  @Test func feedbackDecodesNewAndLegacyMetadata() throws {
    for fields in [
      "", ",\"poster_url\":null,\"duration_seconds\":null",
      ",\"poster_url\":\"https://example.com/poster.jpg\",\"duration_seconds\":65",
    ] {
      let data = Data("{\"id\":\"00000000-0000-4000-8000-000000000601\"\(fields)}".utf8)
      let dto = try MeetPRCodec.decoder.decode(FeedbackVideoDTO.self, from: data)
      let video = dto.toDomain()
      let cover = ChatVideoCoverPresentation(
        posterURL: video.posterURL, durationSeconds: video.durationSeconds)
      #expect(
        cover.posterURL?.absoluteString
          == (fields.contains("https") ? "https://example.com/poster.jpg" : nil))
      #expect(cover.durationText == (fields.contains("65") ? "1:05" : nil))
      let cached = try MeetPRCodec.decoder.decode(
        CoachFeedbackVideo.self, from: MeetPRCodec.encoder.encode(video))
      #expect(cached == video)
    }
  }

  @Test func sharedSetDecodesPosterIntoCoverPresentation() throws {
    let reference = try SetRefV1(
      source: .logged, exerciseName: "Squat", setNumber: 1, setTotal: 3,
      weightKg: "100", reps: 5, repsMax: nil, rpe: "8", dayDate: "2026-11-06",
      setLogId: UUID(), planSetId: nil)
    let message = ChatMessageDTO(
      id: UUID(), conversationID: UUID(), seq: 1, senderID: UUID(), kind: .text,
      body: SetRefCanonicalFormatter.firstLine(for: reference), attachmentID: nil,
      imageURL: nil, imageExpiresIn: nil, setRef: reference,
      videoURL: URL(string: "https://example.com/video.mp4"), clientID: "shared", createdAt: Date())
    let data = try MeetPRCodec.encoder.encode(message)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["poster_url"] = "https://example.com/poster.jpg"
    object["duration_seconds"] = 65
    let decoded = try MeetPRCodec.decoder.decode(
      ChatMessageDTO.self, from: JSONSerialization.data(withJSONObject: object))
    let presentation = try #require(ChatSetCardPresentation(message: decoded.toDomain()))
    #expect(presentation.cover.posterURL?.absoluteString == "https://example.com/poster.jpg")
    #expect(presentation.cover.durationText == "1:05")
  }
}
