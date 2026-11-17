import CoreModels
import Foundation

public enum PendingChatMessage: Hashable, Sendable {
  case text(String)
  case exerciseNote(body: String, reference: ExerciseRefV1)
  case image(Data)
  case video(ChatVideoFile)
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
  public let uploadProgress: Double?
  public let createdAt: Date

  public var sendingProgress: Double? {
    if case .sending = state { return uploadProgress ?? 0 }
    return nil
  }

  public init(
    clientID: String,
    conversationID: UUID,
    senderID: UUID,
    draft: PendingChatMessage,
    state: ChatSendState,
    createdAt: Date = Date(),
    uploadProgress: Double? = nil
  ) {
    self.clientID = clientID
    self.conversationID = conversationID
    self.senderID = senderID
    self.draft = draft
    self.state = state
    self.createdAt = createdAt
    self.uploadProgress = uploadProgress
  }
}
