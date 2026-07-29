import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func chatSetRefFixtureDecodesCardAndVideoFields() throws {
  let response = try MeetPRCodec.decoder.decode(
    ChatMessageResponseDTO.self,
    from: Data(ChatWireFixture.setRefMessageResponse.utf8)
  )
  let message = response.message

  #expect(message.body == ChatWireFixture.setRefFirstLine + "\n看看深度")
  #expect(message.setRef?.version == 1)
  #expect(message.setRef?.exerciseName == "低杠位深蹲")
  #expect(message.setRef?.setNumber == 3)
  #expect(message.setRef?.weightKg == "100")
  #expect(message.setRef?.reps == 5)
  #expect(message.setRef?.rpe == "8.5")
  #expect(message.setRef?.dayDate == "2026-07-27")
  #expect(message.setRef?.setLogId == ChatWireFixture.setLogID)
  #expect(message.videoURL?.absoluteString == "https://oss.example.test/set.mp4?signature=abc")
  #expect(message.videoExpiresIn == 900)

  let domain = message.toDomain()
  #expect(domain.setRef == message.setRef)
  #expect(domain.videoURL == message.videoURL)
  #expect(domain.videoExpiresIn == 900)
}

@Test func readSideSetRefIgnoresUnknownV1FieldsWithoutLooseningStrictCodec() throws {
  let response = try MeetPRCodec.decoder.decode(
    ChatMessageResponseDTO.self,
    from: Data(ChatWireFixture.setRefWithUnknownFieldResponse.utf8)
  )

  #expect(response.message.setRef?.setNumber == 3)

  let strictSetRef = try #require(
    try JSONSerialization.jsonObject(
      with: Data(ChatWireFixture.setRefObjectWithUnknownField.utf8)
    ) as? [String: Any]
  )
  let strictData = try JSONSerialization.data(withJSONObject: strictSetRef)
  #expect(throws: SetRefValidationError.unknownFields(["futureLabel"])) {
    try MeetPRCodec.decoder.decode(SetRefV1.self, from: strictData)
  }
}

@Test func malformedSetRefsInsideMessageArrayDegradeOnlyThoseCardsToText() throws {
  let response = try MeetPRCodec.decoder.decode(
    ChatMessagesResponseDTO.self,
    from: Data(ChatWireFixture.mixedV2MessagesResponse.utf8)
  )

  try #require(response.messages.count == 3)
  #expect(response.messages.map(\.seq) == [40, 41, 42])
  #expect(response.messages[0].body == "未来卡原始 body")
  #expect(response.messages[0].setRef == nil)
  #expect(response.messages[1].body == "类型损坏卡原始 body")
  #expect(response.messages[1].setRef == nil)
  #expect(response.messages[2].body == "正常消息")
  #expect(response.messages[2].setRef == nil)
}

extension ChatWireFixture {
  static let setLogID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x5A, 7)
  )
  static let setRefFirstLine = "[训练分享] 低杠位深蹲 第3组 100kg×5 @RPE8.5 (2026-07-27)"

  static var setRefMessageResponse: String {
    """
    {
      "message": {
        "id": "\(textMessageID.uuidString)",
        "conversation_id": "\(conversationID.uuidString)",
        "seq": 42,
        "sender_id": "\(otherUserID.uuidString)",
        "kind": "text",
        "body": "\(setRefFirstLine)\\n看看深度",
        "attachment_id": null,
        "image_url": null,
        "image_expires_in": null,
        "set_ref": \(setRefObject),
        "video_url": "https://oss.example.test/set.mp4?signature=abc",
        "video_expires_in": 900,
        "client_id": "cli-set-ref",
        "created_at": "2026-07-20T09:12:30.123Z"
      }
    }
    """
  }

  static var setRefWithUnknownFieldResponse: String {
    """
    {
      "message": {
        "id": "\(textMessageID.uuidString)",
        "conversation_id": "\(conversationID.uuidString)",
        "seq": 42,
        "sender_id": "\(otherUserID.uuidString)",
        "kind": "text",
        "body": "\(setRefFirstLine)",
        "attachment_id": null,
        "image_url": null,
        "image_expires_in": null,
        "set_ref": \(setRefObjectWithUnknownField),
        "video_url": null,
        "video_expires_in": null,
        "client_id": "cli-set-ref",
        "created_at": "2026-07-20T09:12:30.123Z"
      }
    }
    """
  }

  static var mixedV2MessagesResponse: String {
    """
    {
      "messages": [
        {
          "id": "\(readMessageID.uuidString)",
          "conversation_id": "\(conversationID.uuidString)",
          "seq": 40,
          "sender_id": "\(otherUserID.uuidString)",
          "kind": "text",
          "body": "未来卡原始 body",
          "attachment_id": null,
          "image_url": null,
          "image_expires_in": null,
          "set_ref": {
            "v": 2,
            "exercise_name": "未来动作",
            "set_number": 1,
            "weight_kg": "100",
            "reps": 5,
            "rpe": "8",
            "day_date": "2026-07-27",
            "set_log_id": "\(setLogID.uuidString)"
          },
          "video_url": null,
          "video_expires_in": null,
          "client_id": "cli-v2",
          "created_at": "2026-07-20T09:10:00.000Z"
        },
        {
          "id": "\(textMessageID.uuidString)",
          "conversation_id": "\(conversationID.uuidString)",
          "seq": 41,
          "sender_id": "\(otherUserID.uuidString)",
          "kind": "text",
          "body": "类型损坏卡原始 body",
          "attachment_id": null,
          "image_url": null,
          "image_expires_in": null,
          "set_ref": {
            "v": 1,
            "exercise_name": "深蹲",
            "set_number": "bad",
            "weight_kg": "100",
            "reps": 5,
            "rpe": "8",
            "day_date": "2026-07-27",
            "set_log_id": "\(setLogID.uuidString)"
          },
          "video_url": null,
          "video_expires_in": null,
          "client_id": "cli-malformed",
          "created_at": "2026-07-20T09:11:00.000Z"
        },
        \(textMessageObject(id: imageMessageID, seq: 42, body: "正常消息"))
      ],
      "meta": {
        "other_last_read": null,
        "has_more": false
      }
    }
    """
  }

  static var setRefObjectWithUnknownField: String {
    var object = setRefObject
    object.removeLast()
    return object + #","future_label":"server-added"}"#
  }

  private static var setRefObject: String {
    """
    {
      "v": 1,
      "exercise_name": "低杠位深蹲",
      "set_number": 3,
      "weight_kg": "100",
      "reps": 5,
      "rpe": "8.5",
      "day_date": "2026-07-27",
      "set_log_id": "\(setLogID.uuidString)"
    }
    """
  }

  private static func textMessageObject(id: UUID, seq: Int, body: String) -> String {
    """
    {
      "id": "\(id.uuidString)",
      "conversation_id": "\(conversationID.uuidString)",
      "seq": \(seq),
      "sender_id": "\(otherUserID.uuidString)",
      "kind": "text",
      "body": "\(body)",
      "attachment_id": null,
      "image_url": null,
      "image_expires_in": null,
      "client_id": "cli-\(seq)",
      "created_at": "2026-07-20T09:08:00.000Z"
    }
    """
  }
}
