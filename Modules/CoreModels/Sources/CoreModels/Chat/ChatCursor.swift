import Foundation

public struct ChatCursor: Codable, Hashable, Sendable {
  public let messageID: UUID
  public let seq: Int

  public init(messageID: UUID, seq: Int) {
    self.messageID = messageID
    self.seq = seq
  }

  private enum CodingKeys: String, CodingKey {
    case messageID = "messageId"
    case seq
  }
}
