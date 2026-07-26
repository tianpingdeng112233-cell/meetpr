import Foundation

/// §2 radius canon: exactly four steps — 4 (micro markers), 12 (small
/// controls/chips), 16 (cards & sheets), 999 (pills). Every legacy name maps
/// onto one of those so no view can render an off-canon corner.
@frozen public enum MeetPRRadius {
  public static let micro: CGFloat = 4
  public static let control: CGFloat = 12
  public static let card: CGFloat = 16
  public static let pill: CGFloat = 999

  // Legacy names, snapped to the canon.
  public static let point1: CGFloat = micro
  public static let point1AndHalf: CGFloat = micro
  public static let point2: CGFloat = micro
  public static let point3: CGFloat = micro
  public static let point4: CGFloat = micro
  public static let point5: CGFloat = micro
  public static let point6: CGFloat = micro
  public static let point7: CGFloat = micro
  public static let point8: CGFloat = micro
  public static let point9: CGFloat = control
  public static let chip: CGFloat = control
  public static let point11: CGFloat = control
  public static let point13: CGFloat = control
  public static let point14: CGFloat = card
  public static let point15: CGFloat = card
  public static let point18: CGFloat = card
  public static let modal: CGFloat = card
  public static let point22: CGFloat = card
  public static let point24: CGFloat = card
  public static let point28: CGFloat = card
  public static let point30: CGFloat = card

  // Migration aliases used by existing components.
  // swiftlint:disable:next identifier_name
  public static let sm = control
  // swiftlint:disable:next identifier_name
  public static let md = control
  // swiftlint:disable:next identifier_name
  public static let lg = card
  // swiftlint:disable:next identifier_name
  public static let xl = card
}
