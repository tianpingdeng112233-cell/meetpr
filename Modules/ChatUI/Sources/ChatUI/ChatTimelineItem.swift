import CoreModels
import Foundation

public enum ChatTimelineItem: Identifiable, Sendable {
  case message(ChatMessage, sentAt: Date? = nil)
  case pending(ChatOutboxItem)

  public var id: String {
    switch self {
    case .message(let message, let sentAt):
      sentAt == nil ? "message-\(message.id)" : "pending-\(message.clientID)"
    case .pending(let item):
      "pending-\(item.clientID)"
    }
  }

  /// A locally sent row retains its slot and grouping until this session ends.
  public var groupingDate: Date {
    switch self {
    case .message(let message, let sentAt): sentAt ?? message.createdAt
    case .pending(let item): item.createdAt
    }
  }

  /// The label adopts the server timestamp once sending succeeds.
  public var timestamp: Date {
    switch self {
    case .message(let message, _): message.createdAt
    case .pending(let item): item.createdAt
    }
  }
}

extension ConversationViewModel {
  public var timelineItems: [ChatTimelineItem] {
    var history: [ChatTimelineItem] = []
    var local: [ChatTimelineItem] = []
    for message in renderedMessages {
      let sentAt =
        message.senderID == currentUserID
        ? sendCoordinator.sentAt(in: conversationID, clientID: message.clientID) : nil
      let item = ChatTimelineItem.message(message, sentAt: sentAt)
      if sentAt == nil { history.append(item) } else { local.append(item) }
    }
    local.append(contentsOf: pending.map(ChatTimelineItem.pending))
    // Keep server history in its original sequence order. Only insert the
    // locally authored rows by their original send time, including slow uploads.
    for item in local.sorted(by: { $0.groupingDate < $1.groupingDate }) {
      let index = history.firstIndex { $0.groupingDate > item.groupingDate } ?? history.endIndex
      history.insert(item, at: index)
    }
    return history
  }
}
