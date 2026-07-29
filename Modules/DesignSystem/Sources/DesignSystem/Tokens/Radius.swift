import Foundation

/// §2 radius canon: 4 / 10 / 12 / 16 / 20 / 999.
@frozen public enum MeetPRRadius {
  public static let micro: CGFloat = 4
  public static let inset: CGFloat = 10
  public static let control: CGFloat = 12
  public static let card: CGFloat = 16
  public static let modal: CGFloat = 20
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
  public static let point8: CGFloat = inset
  public static let point9: CGFloat = inset
  public static let chip: CGFloat = control
  public static let point11: CGFloat = control
  public static let point13: CGFloat = control
  public static let point14: CGFloat = card
  public static let point15: CGFloat = card
  public static let point18: CGFloat = modal
  public static let point22: CGFloat = modal
  public static let point24: CGFloat = modal
  public static let point28: CGFloat = modal
  public static let point30: CGFloat = modal

  // Migration aliases used by existing components.
  // swiftlint:disable:next identifier_name
  public static let sm = control
  // swiftlint:disable:next identifier_name
  public static let md = inset
  // swiftlint:disable:next identifier_name
  public static let lg = control
  // swiftlint:disable:next identifier_name
  public static let xl = card
}
