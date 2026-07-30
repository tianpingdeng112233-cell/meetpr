import CoreModels
import Foundation
import RepositoryContracts

enum CoachTodayTodoList {
  enum Dot: Hashable, Sendable {
    case gold
    case danger
  }

  enum Destination: Hashable, Sendable {
    case messages
    case studentChat(UUID)
    case students
  }

  struct Item: Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let tag: String
    let dot: Dot
    let destination: Destination
  }

  static func makeItems(
    videos: [PendingVideoItem],
    conversations: [ChatConversation],
    rosterRows: [StudentRosterRowModel],
    applications: [CoachBindRequestItem],
    now: Date
  ) -> [Item] {
    var items: [Item] = []

    videoItem(videos: videos, now: now).map { items.append($0) }
    unreadItem(conversations: conversations).map { items.append($0) }
    items.append(contentsOf: attentionItems(rows: rosterRows))
    applicationItem(applications: applications, now: now).map { items.append($0) }

    return items
  }

  private static func videoItem(videos: [PendingVideoItem], now: Date) -> Item? {
    guard let earliestVideo = videos.min(by: { $0.uploadedAt < $1.uploadedAt }) else {
      return nil
    }
    return Item(
      id: "videos",
      title: CoachTodayStrings.pendingVideosTitle(videos.count),
      subtitle: CoachTodayStrings.earliestVideoSubtitle(
        CoachStudentFormatting.relativeText(earliestVideo.uploadedAt, now: now)
      ),
      tag: CoachTodayStrings.awaitingFeedback,
      dot: .gold,
      destination: .messages
    )
  }

  private static func unreadItem(conversations: [ChatConversation]) -> Item? {
    let unreadConversations = conversations.filter { $0.unreadCount > 0 }
    // Intentional prototype deviation: surface the real unread message total,
    // not merely the number of conversations with unread messages.
    let unreadCount = unreadConversations.reduce(0) { $0 + $1.unreadCount }
    guard unreadCount > 0 else { return nil }
    return Item(
      id: "unread",
      title: CoachTodayStrings.unreadMessagesTitle(unreadCount),
      subtitle: unreadConversations.map(\.otherPartyName).joined(separator: " · "),
      tag: CoachTodayStrings.unread,
      dot: .danger,
      destination: .messages
    )
  }

  private static func attentionItems(rows: [StudentRosterRowModel]) -> [Item] {
    rows.compactMap { row in
      guard let daysMissed = row.triageSignals.compactMap(missedDays).max() else {
        return nil
      }
      return Item(
        id: "attention-\(row.id.uuidString)",
        title: CoachTodayStrings.notTrainedTitle(
          studentName: row.student.displayName,
          daysMissed: daysMissed
        ),
        subtitle: CoachTodayStrings.askHowThingsAreGoing,
        tag: CoachTodayStrings.needsAttention,
        dot: .danger,
        destination: .studentChat(row.student.id)
      )
    }
  }

  private static func applicationItem(
    applications: [CoachBindRequestItem],
    now: Date
  ) -> Item? {
    guard let earliest = applications.min(by: { $0.submittedAt < $1.submittedAt }) else {
      return nil
    }
    let waitingText = CoachOnboardingDisplay.waitingText(since: earliest.submittedAt, now: now)
    let isSingleApplication = applications.count == 1
    return Item(
      id: "applications",
      title:
        isSingleApplication
        ? CoachTodayStrings.singleApplicationTitle(earliest.displayName)
        : CoachTodayStrings.multipleApplicationsTitle(applications.count),
      subtitle:
        isSingleApplication
        ? waitingText
        : CoachTodayStrings.earliestApplicationSubtitle(waitingText),
      tag: CoachTodayStrings.newApplication,
      dot: .gold,
      destination: .students
    )
  }

  private static func missedDays(_ signal: TriageSignal) -> Int? {
    if case .notTrained(let daysMissed) = signal {
      return daysMissed
    }
    return nil
  }
}
