import Foundation

// Mirrors the module-strings pattern (`StudentStrings`) so widget copy is
// typed at the call site; the appex's own bundle hosts the string catalog.
enum WidgetStrings {
  static let restTimerTitle = localized("widget.restTimer.title")
  static let restTimerFinished = localized("widget.restTimer.finished")
  static let restTimerFinishedCompact = localized("widget.restTimer.finishedCompact")

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key)
  }
}
