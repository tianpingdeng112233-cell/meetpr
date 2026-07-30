import CoreModels
import Foundation

struct CoachInboxRow: Identifiable, Equatable, Sendable {
  let studentID: UUID
  let studentName: String
  let lastPreview: String
  let unreadCount: Int
  let pendingVideoCount: Int
  let latestActivityAt: Date?
  let conversation: ChatConversation?
  let videoGroup: PendingVideoStudentGroup?

  var id: UUID { studentID }
  var hasUnread: Bool { unreadCount > 0 }
  var hasPendingVideos: Bool { pendingVideoCount > 0 }

  fileprivate var priority: Int {
    (hasPendingVideos ? 2 : 0) + (hasUnread ? 1 : 0)
  }
}

enum CoachInboxPresentation {
  static func count(
    conversations: [ChatConversation],
    pendingVideoCount: Int
  ) -> Int {
    pendingVideoCount
      + latestConversationsByStudent(conversations).values.reduce(0) {
        $0 + $1.unreadCount
      }
  }

  static func rows(
    conversations: [ChatConversation],
    videoGroups: [PendingVideoStudentGroup],
    now: Date
  ) -> [CoachInboxRow] {
    let conversationsByStudent = latestConversationsByStudent(conversations)
    let groupsByStudent = Dictionary(
      uniqueKeysWithValues: videoGroups.map { ($0.studentID, $0) }
    )
    let studentIDs = Set(conversationsByStudent.keys).union(groupsByStudent.keys)

    return studentIDs.map { studentID in
      let conversation = conversationsByStudent[studentID]
      let videoGroup = groupsByStudent[studentID]
      let conversationName = conversation?.otherPartyName.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      let studentName =
        conversationName.flatMap { $0.isEmpty ? nil : $0 }
        ?? videoGroup?.studentName
        ?? ""
      let latestActivityAt = [
        conversation?.lastMessageAt,
        videoGroup?.latestUploadedAt,
      ].compactMap(\.self).max()

      return CoachInboxRow(
        studentID: studentID,
        studentName: studentName,
        lastPreview: preview(
          conversation: conversation,
          videoGroup: videoGroup,
          now: now
        ),
        unreadCount: conversation?.unreadCount ?? 0,
        pendingVideoCount: videoGroup?.count ?? 0,
        latestActivityAt: latestActivityAt,
        conversation: conversation,
        videoGroup: videoGroup
      )
    }
    .sorted { lhs, rhs in
      if lhs.priority != rhs.priority {
        return lhs.priority > rhs.priority
      }
      if lhs.latestActivityAt != rhs.latestActivityAt {
        return (lhs.latestActivityAt ?? .distantPast) > (rhs.latestActivityAt ?? .distantPast)
      }
      let nameOrder = lhs.studentName.localizedStandardCompare(rhs.studentName)
      if nameOrder != .orderedSame {
        return nameOrder == .orderedAscending
      }
      return lhs.studentID.uuidString < rhs.studentID.uuidString
    }
  }

  private static func latestConversationsByStudent(
    _ conversations: [ChatConversation]
  ) -> [UUID: ChatConversation] {
    conversations.reduce(into: [:]) { result, conversation in
      guard let existing = result[conversation.otherPartyID] else {
        result[conversation.otherPartyID] = conversation
        return
      }
      if isLater(conversation, than: existing) {
        result[conversation.otherPartyID] = conversation
      }
    }
  }

  private static func isLater(
    _ candidate: ChatConversation,
    than existing: ChatConversation
  ) -> Bool {
    let candidateDate = candidate.lastMessageAt ?? .distantPast
    let existingDate = existing.lastMessageAt ?? .distantPast
    if candidateDate != existingDate {
      return candidateDate > existingDate
    }
    return candidate.id.uuidString > existing.id.uuidString
  }

  private static func preview(
    conversation: ChatConversation?,
    videoGroup: PendingVideoStudentGroup?,
    now: Date
  ) -> String {
    if let videoGroup {
      return CoachInboxStrings.pendingVideoPreview(
        count: videoGroup.count,
        relativeTime: CoachStudentFormatting.relativeText(
          videoGroup.latestUploadedAt,
          now: now
        )
      )
    }
    return conversation?.lastMessagePreview ?? CoachInboxStrings.noMessages
  }
}
