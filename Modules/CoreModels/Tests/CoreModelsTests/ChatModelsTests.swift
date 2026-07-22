import Foundation
import Testing

@testable import CoreModels

@Test func chatModelsCodablePreservesAcronymFields() throws {
  let messageID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 1))
  let conversationID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 2)
  )
  let senderID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 3))
  let attachmentID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 4)
  )
  let message = ChatMessage(
    id: messageID,
    conversationID: conversationID,
    seq: 41,
    senderID: senderID,
    kind: .image,
    text: nil,
    attachmentID: attachmentID,
    imageURL: URL(string: "https://example.test/image.jpg"),
    imageExpiresIn: 900,
    clientID: "cli-xyz",
    createdAt: Date(timeIntervalSince1970: 1_768_900_000)
  )

  let data = try MeetPRCodec.encoder.encode(message)
  let decoded = try MeetPRCodec.decoder.decode(ChatMessage.self, from: data)
  #expect(decoded == message)

  let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  #expect(json["conversation_id"] as? String == conversationID.uuidString)
  #expect(json["sender_id"] as? String == senderID.uuidString)
  #expect(json["attachment_id"] as? String == attachmentID.uuidString)
  #expect(json["client_id"] as? String == "cli-xyz")
}

@Test func activeCoachContextHasPublicConstructionAndCodable() throws {
  let coachID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 5))
  let context = ActiveCoachContext(coachID: coachID, coachDisplayName: "周教练")

  let data = try MeetPRCodec.encoder.encode(context)
  #expect(try MeetPRCodec.decoder.decode(ActiveCoachContext.self, from: data) == context)
}
