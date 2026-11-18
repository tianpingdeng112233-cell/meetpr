import CoreModels
import Foundation

extension ChatSendCoordinator {
  @discardableResult
  public func sendVideo(
    in conversationID: UUID, video: ChatVideoFile, clientID: String? = nil
  ) -> String? {
    guard !isDraining else {
      try? FileManager.default.removeItem(at: video.fileURL)
      return nil
    }
    return enqueue(.video(video), in: conversationID, clientID: clientID ?? Self.makeClientID())
  }

  func updateVideoProgress(_ item: ChatOutboxItem, progress: Double) {
    guard
      let index = outboxesByConversationID[item.conversationID]?.firstIndex(where: {
        $0.clientID == item.clientID
      }), let current = outboxesByConversationID[item.conversationID]?[index],
      case .sending = current.state
    else { return }
    outboxesByConversationID[item.conversationID]?[index] = ChatOutboxItem(
      clientID: current.clientID, conversationID: current.conversationID,
      senderID: current.senderID, draft: current.draft, state: current.state,
      createdAt: current.createdAt, uploadProgress: min(1, max(0, progress)))
  }

  func cleanupLocalVideo(_ item: ChatOutboxItem) {
    if case .video(let video) = item.draft {
      try? FileManager.default.removeItem(at: video.fileURL)
    }
  }

}
