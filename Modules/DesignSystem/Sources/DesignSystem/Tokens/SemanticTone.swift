import SwiftUI

public enum MeetPRSemanticTone: Equatable, Sendable {
  case action
  case inProgress
  case notCompleted
  case danger
  case completed
  case neutral
  /// The numeric count badge on an entry point. Deliberately distinct from
  /// ``danger``: the mockups draw counters in the platform alert red while a
  /// failed set stays on the softer brand red.
  case unreadBadge

  public var color: Color {
    switch self {
    case .action, .inProgress:
      Color.MeetPR.gold500
    case .notCompleted, .danger:
      Color.MeetPR.danger
    case .completed:
      Color.MeetPR.success
    case .neutral:
      Color.MeetPR.textTertiary
    case .unreadBadge:
      Color.MeetPR.unread
    }
  }

  /// A count badge — red. An inline "there is something new here" dot is a
  /// different affordance and uses ``inProgress`` (gold) per the mockups.
  public static let unread = MeetPRSemanticTone.unreadBadge
}
