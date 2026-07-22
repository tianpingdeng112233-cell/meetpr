import Foundation

public struct ChatConversation: Codable, Identifiable, Hashable, Sendable {
  public let id: UUID
  public let otherPartyID: UUID
  public let otherPartyName: String
  public let lastMessagePreview: String?
  public let lastMessageAt: Date?
  public let unreadCount: Int
  public let myLastRead: ChatCursor?
  public let otherLastRead: ChatCursor?

  public init(
    id: UUID,
    otherPartyID: UUID,
    otherPartyName: String,
    lastMessagePreview: String?,
    lastMessageAt: Date?,
    unreadCount: Int,
    myLastRead: ChatCursor?,
    otherLastRead: ChatCursor?
  ) {
    self.id = id
    self.otherPartyID = otherPartyID
    self.otherPartyName = otherPartyName
    self.lastMessagePreview = lastMessagePreview
    self.lastMessageAt = lastMessageAt
    self.unreadCount = unreadCount
    self.myLastRead = myLastRead
    self.otherLastRead = otherLastRead
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case otherPartyID = "otherPartyId"
    case otherPartyName
    case lastMessagePreview
    case lastMessageAt
    case unreadCount
    case myLastRead
    case otherLastRead
  }
}
