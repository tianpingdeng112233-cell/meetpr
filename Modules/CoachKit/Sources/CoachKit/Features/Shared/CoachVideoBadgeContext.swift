import SwiftUI

private struct CoachVideoBadgeNameKey: EnvironmentKey {
  static let defaultValue: String? = nil
}

extension EnvironmentValues {
  var coachVideoBadgeName: String? {
    get { self[CoachVideoBadgeNameKey.self] }
    set { self[CoachVideoBadgeNameKey.self] = newValue }
  }
}
