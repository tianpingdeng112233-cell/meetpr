import Foundation

@frozen public enum MeetPRSpacing {
  public static let zero: CGFloat = 0
  public static let point1: CGFloat = 1
  public static let point1AndHalf: CGFloat = 1.5
  public static let point2: CGFloat = 2
  public static let point3: CGFloat = 3
  public static let space1: CGFloat = 4
  public static let point5: CGFloat = 5
  public static let point6: CGFloat = 6
  public static let point7: CGFloat = 7
  public static let space2: CGFloat = 8
  public static let point9: CGFloat = 9
  public static let point10: CGFloat = 10
  public static let point11: CGFloat = 11
  public static let space3: CGFloat = 12
  public static let point13: CGFloat = 13
  public static let point14: CGFloat = 14
  public static let point15: CGFloat = 15
  public static let space4: CGFloat = 16
  public static let point18: CGFloat = 18
  public static let space5: CGFloat = 20
  public static let point22: CGFloat = 22
  public static let space6: CGFloat = 24
  public static let point26: CGFloat = 26
  public static let point28: CGFloat = 28
  public static let point30: CGFloat = 30
  public static let point32: CGFloat = 32
  public static let point34: CGFloat = 34
  public static let point36: CGFloat = 36
  public static let point40: CGFloat = 40
  public static let point48: CGFloat = 48
  public static let point52: CGFloat = 52
  public static let point56: CGFloat = 56
  public static let point64: CGFloat = 64

  /// Main tab screens use the 20pt value measured in the pixel-reference mockups.
  public static let pageHorizontal = space5
  public static let compactPageHorizontal = space4
  public static let cardHorizontal = space4
  public static let minimumHitTarget: CGFloat = 44
  public static let completionControlHeight: CGFloat = 58

  // Migration aliases used by existing screens while W2-W4 adopt semantic names.
  // swiftlint:disable:next identifier_name
  public static let xs = space1
  // swiftlint:disable:next identifier_name
  public static let sm = space2
  // swiftlint:disable:next identifier_name
  public static let md = space3
  public static let base = space4
  // swiftlint:disable:next identifier_name
  public static let lg = space6
  // swiftlint:disable:next identifier_name
  public static let xl: CGFloat = 32
  public static let xxl: CGFloat = 48
  public static let xxxl: CGFloat = 64
}
