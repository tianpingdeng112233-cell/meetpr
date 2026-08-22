import Foundation

enum CoachInboxStrings {
  static let title = CoachLocalization.localized("coach.inbox.title")
  static let hint = CoachLocalization.localized("coach.inbox.hint")
  static let noMessages = CoachLocalization.localized("coach.inbox.noMessages")
  static let emptyTitle = CoachLocalization.localized("coach.inbox.emptyTitle")
  static let emptySubtitle = CoachLocalization.localized("coach.inbox.emptySubtitle")
  static let loadFailed = CoachLocalization.localized("coach.inbox.loadFailed")
  static let loading = CoachLocalization.localized("coach.inbox.loading")
  static let playPendingVideos = CoachLocalization.localized("coach.inbox.playPendingVideos")

  static func eyebrow(_ count: Int) -> String {
    CoachLocalization.localized("coach.inbox.eyebrow \(count)")
  }

  static func pendingVideoPreview(count: Int, relativeTime: String) -> String {
    CoachLocalization.localized("coach.inbox.pendingVideoPreview \(count) \(relativeTime)")
  }

  static func unreadAccessibility(_ count: Int) -> String {
    CoachLocalization.localized("coach.inbox.unreadAccessibility \(count)")
  }

  static func pendingVideosAccessibility(name: String, count: Int) -> String {
    CoachLocalization.localized("coach.inbox.pendingVideosAccessibility \(name) \(count)")
  }
}
