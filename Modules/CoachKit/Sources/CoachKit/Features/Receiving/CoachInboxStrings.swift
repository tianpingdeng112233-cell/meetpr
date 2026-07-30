import Foundation

enum CoachInboxStrings {
  static let title = CoachLocalization.localized("coach.inbox.title")
  static let hint = CoachLocalization.localized("coach.inbox.hint")
  static let noMessages = CoachLocalization.localized("coach.inbox.noMessages")
  static let emptyTitle = CoachLocalization.localized("coach.inbox.emptyTitle")
  static let emptySubtitle = CoachLocalization.localized("coach.inbox.emptySubtitle")
  static let playPendingVideos = CoachLocalization.localized("coach.inbox.playPendingVideos")

  static func eyebrow(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.inbox.eyebrow",
      values: ["count": count.formatted()]
    )
  }

  static func pendingVideoPreview(count: Int, relativeTime: String) -> String {
    CoachLocalization.replacing(
      "coach.inbox.pendingVideoPreview",
      values: [
        "count": count.formatted(),
        "relativeTime": relativeTime,
      ]
    )
  }

  static func unreadAccessibility(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.inbox.unreadAccessibility",
      values: ["count": count.formatted()]
    )
  }

  static func pendingVideosAccessibility(name: String, count: Int) -> String {
    CoachLocalization.replacing(
      "coach.inbox.pendingVideosAccessibility",
      values: [
        "name": name,
        "count": count.formatted(),
      ]
    )
  }
}
