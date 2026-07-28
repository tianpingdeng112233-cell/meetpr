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

@Test func malformedSetRefsInsideDomainMessageArrayAreLocallyLossy() throws {
  let conversationID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 9)
  )
  let senderID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 8)
  )
  let setLogID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 7)
  )
  let data = Data(
    malformedSetRefArrayJSON(
      conversationID: conversationID,
      senderID: senderID,
      setLogID: setLogID
    ).utf8
  )

  let messages = try MeetPRCodec.decoder.decode([ChatMessage].self, from: data)

  #expect(messages.count == 3)
  #expect(messages.map(\.seq) == [1, 2, 3])
  #expect(messages[0].text == "未来卡原始文本")
  #expect(messages[0].setRef == nil)
  #expect(messages[1].text == "类型损坏卡原始文本")
  #expect(messages[1].setRef == nil)
  #expect(messages[2].text == "正常消息")
  #expect(messages[2].setRef == nil)
}

private func malformedSetRefArrayJSON(
  conversationID: UUID,
  senderID: UUID,
  setLogID: UUID
) -> String {
  let context = DomainSetRefFixtureContext(
    conversationID: conversationID,
    senderID: senderID,
    setLogID: setLogID
  )
  return """
    [
      \(domainSetRefMessageJSON(
      context: context,
      seq: 1,
      text: "未来卡原始文本",
      version: 2,
      setNumberJSON: "1"
    )),
      \(domainSetRefMessageJSON(
      context: context,
      seq: 2,
      text: "类型损坏卡原始文本",
      version: 1,
      setNumberJSON: #""bad""#
    )),
      \(domainTextMessageJSON(
      id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 3)),
      conversationID: conversationID,
      senderID: senderID,
      seq: 3,
      text: "正常消息"
    ))
    ]
    """
}

private struct DomainSetRefFixtureContext {
  let conversationID: UUID
  let senderID: UUID
  let setLogID: UUID
}

private func domainSetRefMessageJSON(
  context: DomainSetRefFixtureContext,
  seq: Int,
  text: String,
  version: Int,
  setNumberJSON: String
) -> String {
  """
  {
    "id": "00000000-0000-4000-8000-00000000000\(seq)",
    "conversation_id": "\(context.conversationID.uuidString)",
    "seq": \(seq),
    "sender_id": "\(context.senderID.uuidString)",
    "kind": "text",
    "text": "\(text)",
    "set_ref": {
      "v": \(version),
      "exercise_name": "深蹲",
      "set_number": \(setNumberJSON),
      "weight_kg": "100",
      "reps": 5,
      "rpe": "8",
      "day_date": "2026-07-27",
      "set_log_id": "\(context.setLogID.uuidString)"
    },
    "client_id": "set-ref-\(seq)",
    "created_at": "2026-07-20T09:10:00.000Z"
  }
  """
}

private func domainTextMessageJSON(
  id: UUID,
  conversationID: UUID,
  senderID: UUID,
  seq: Int,
  text: String
) -> String {
  """
  {
    "id": "\(id.uuidString)",
    "conversation_id": "\(conversationID.uuidString)",
    "seq": \(seq),
    "sender_id": "\(senderID.uuidString)",
    "kind": "text",
    "text": "\(text)",
    "client_id": "client-\(seq)",
    "created_at": "2026-07-20T09:08:00.000Z"
  }
  """
}
