import Foundation

@frozen public enum MeetPRRadius {
  public static let point1: CGFloat = 1
  public static let point1AndHalf: CGFloat = 1.5
  public static let point2: CGFloat = 2
  public static let point3: CGFloat = 3
  public static let point4: CGFloat = 4
  public static let point5: CGFloat = 5
  public static let point6: CGFloat = 6
  public static let point7: CGFloat = 7
  public static let point8: CGFloat = 8
  public static let point9: CGFloat = 9
  public static let chip: CGFloat = 10
  public static let point11: CGFloat = 11
  public static let control: CGFloat = 12
  public static let point13: CGFloat = 13
  public static let point14: CGFloat = 14
  public static let point15: CGFloat = 15
  public static let card: CGFloat = 16
  public static let point18: CGFloat = 18
  public static let modal: CGFloat = 20
  public static let point22: CGFloat = 22
  public static let point24: CGFloat = 24
  public static let point28: CGFloat = 28
  public static let point30: CGFloat = 30
  public static let pill: CGFloat = 999

  // Migration aliases used by existing components.
  // swiftlint:disable:next identifier_name
  public static let sm = chip
  // swiftlint:disable:next identifier_name
  public static let md = control
  // swiftlint:disable:next identifier_name
  public static let lg = card
  // swiftlint:disable:next identifier_name
  public static let xl = modal
}
