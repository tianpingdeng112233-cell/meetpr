import Foundation

public enum RealtimeEvent: Equatable, Sendable {
  case hello
  case chatMessage(conversationID: UUID, seq: Int, senderID: UUID)
  case chatRead(conversationID: UUID, userID: UUID, lastReadSeq: Int)

  /// Returns `nil` for unknown or malformed events instead of throwing.
  ///
  /// The realtime channel is intentionally forward-compatible: adding a new
  /// server event must never make an older client abandon the whole stream.
  public static func decode(_ data: Data) -> RealtimeEvent? {
    guard let envelope = try? JSONDecoder().decode(EventTypeEnvelope.self, from: data) else {
      return nil
    }

    switch envelope.type {
    case "hello":
      return .hello
    case "chat.message":
      guard let event = try? JSONDecoder().decode(ChatMessageEnvelope.self, from: data) else {
        return nil
      }
      return .chatMessage(
        conversationID: event.payload.conversationID,
        seq: event.payload.seq,
        senderID: event.payload.senderID
      )
    case "chat.read":
      guard let event = try? JSONDecoder().decode(ChatReadEnvelope.self, from: data) else {
        return nil
      }
      return .chatRead(
        conversationID: event.payload.conversationID,
        userID: event.payload.userID,
        lastReadSeq: event.payload.lastReadSeq
      )
    default:
      // Unknown event types are an extension point, not a decoding failure.
      return nil
    }
  }
}

private struct EventTypeEnvelope: Decodable {
  let type: String
}

private struct ChatMessageEnvelope: Decodable {
  let payload: ChatMessagePayload
}

private struct ChatReadEnvelope: Decodable {
  let payload: ChatReadPayload
}

private struct ChatMessagePayload: Decodable {
  let conversationID: UUID
  let seq: Int
  let senderID: UUID

  private enum CodingKeys: String, CodingKey {
    case conversationID = "conversation_id"
    case seq
    case senderID = "sender_id"
  }
}

private struct ChatReadPayload: Decodable {
  let conversationID: UUID
  let userID: UUID
  let lastReadSeq: Int

  private enum CodingKeys: String, CodingKey {
    case conversationID = "conversation_id"
    case userID = "user_id"
    case lastReadSeq = "last_read_seq"
  }
}
