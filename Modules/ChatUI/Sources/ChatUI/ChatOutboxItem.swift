import CoreModels
import Foundation

public enum PendingChatMessage: Hashable, Sendable {
  case text(String)
  case image(Data)
}

public enum ChatSendState: Sendable {
  case sending
  case failed(any Error)
  case confirmed(ChatMessage)
}

public struct ChatOutboxItem: Sendable {
  public let clientID: String
  public let conversationID: UUID
  public let senderID: UUID
  public let draft: PendingChatMessage
  public let state: ChatSendState

  public init(
    clientID: String,
    conversationID: UUID,
    senderID: UUID,
    draft: PendingChatMessage,
    state: ChatSendState
  ) {
    self.clientID = clientID
    self.conversationID = conversationID
    self.senderID = senderID
    self.draft = draft
    self.state = state
  }
}
