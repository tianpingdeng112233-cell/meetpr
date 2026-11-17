import SwiftUI

private struct StudentPresentationBlockedKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// Ancestor-owned notices and modals take priority over automatic student setup.
  public var isStudentPresentationBlocked: Bool {
    get { self[StudentPresentationBlockedKey.self] }
    set { self[StudentPresentationBlockedKey.self] = newValue }
  }
}

/// Child-owned workout dialogs report their existing presentation state upward.
struct TrainingPresentationBlockedKey: PreferenceKey {
  static let defaultValue = false

  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}
