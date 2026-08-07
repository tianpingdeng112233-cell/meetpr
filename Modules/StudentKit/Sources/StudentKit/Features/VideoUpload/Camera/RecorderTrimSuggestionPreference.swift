import Foundation

struct RecorderTrimSuggestionState: Equatable, Sendable {
  private(set) var isPermanentlyDisabled: Bool
  private(set) var hasCompletedTrim = false

  init(isPermanentlyDisabled: Bool) {
    self.isPermanentlyDisabled = isPermanentlyDisabled
  }

  var shouldShow: Bool {
    !isPermanentlyDisabled && !hasCompletedTrim
  }

  mutating func completeTrim() {
    hasCompletedTrim = true
  }

  mutating func disablePermanently() {
    isPermanentlyDisabled = true
  }
}

enum RecorderTrimSuggestionPreference {
  private static let key = "videoRecorder.neverSuggestTrim"

  static func isPermanentlyDisabled(in defaults: UserDefaults = .standard) -> Bool {
    defaults.bool(forKey: key)
  }

  static func disablePermanently(in defaults: UserDefaults = .standard) {
    defaults.set(true, forKey: key)
  }
}
