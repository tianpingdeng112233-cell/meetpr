import Foundation

public struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
  public let id: UUID
  public let conversationID: UUID
  public let seq: Int
  public let senderID: UUID
  public let kind: ChatMessageKind
  public let text: String?
  public let attachmentID: UUID?
  public let imageURL: URL?
  public let imageExpiresIn: Int?
  public let clientID: String
  public let createdAt: Date

  public init(
    id: UUID,
    conversationID: UUID,
    seq: Int,
    senderID: UUID,
    kind: ChatMessageKind,
    text: String?,
    attachmentID: UUID?,
    imageURL: URL?,
    imageExpiresIn: Int?,
    clientID: String,
    createdAt: Date
  ) {
    self.id = id
    self.conversationID = conversationID
    self.seq = seq
    self.senderID = senderID
    self.kind = kind
    self.text = text
    self.attachmentID = attachmentID
    self.imageURL = imageURL
    self.imageExpiresIn = imageExpiresIn
    self.clientID = clientID
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case conversationID = "conversationId"
    case seq
    case senderID = "senderId"
    case kind
    case text
    case attachmentID = "attachmentId"
    case imageURL = "imageUrl"
    case imageExpiresIn
    case clientID = "clientId"
    case createdAt
  }
}
