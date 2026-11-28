import SwiftUI

/// Set by full-screen loading placeholders that stand between a cold start and
/// the first usable screen (spec 099). The launch splash stays up while any
/// view in the tree reports it; a tree that reports nothing counts as ready.
public struct LaunchBlockingPreferenceKey: PreferenceKey {
  public static let defaultValue = false

  public static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

extension View {
  /// Marks a full-screen loading placeholder as "first screen not ready yet".
  public func launchBlocking() -> some View {
    preference(key: LaunchBlockingPreferenceKey.self, value: true)
  }
}
