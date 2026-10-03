import Foundation
import Observation

/// Transient state shared by the inline and expanded surfaces of one set entry.
@MainActor @Observable
final class SetEntryVideoPlaybackState {
  enum Speed: Double, CaseIterable, Sendable {
    case double = 2
    case oneAndHalf = 1.5
    case normal = 1
    case half = 0.5

    var label: String {
      rawValue.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))) + "×"
    }
  }

  private(set) var isPlaying = false
  private(set) var isExpanded = false
  private(set) var position: Double = 0
  private(set) var duration: Double = 0
  private(set) var speed: Speed = .normal

  func togglePlayback() { isPlaying.toggle() }
  func pause() { isPlaying = false }
  func setSpeed(_ speed: Speed) { self.speed = speed }
  func toggleExpanded() { isExpanded.toggle() }

  func updateDuration(_ seconds: Double) {
    guard seconds.isFinite, seconds >= 0 else { return }
    duration = seconds
    position = min(position, duration)
  }

  func seek(to seconds: Double) {
    guard seconds.isFinite else { return }
    position = min(max(0, seconds), duration)
  }

  /// Returns true when the return action was consumed by collapsing playback.
  @discardableResult
  func handleBack() -> Bool {
    guard isExpanded else { return false }
    isExpanded = false
    return true
  }

  func stop() {
    isPlaying = false
    isExpanded = false
    position = 0
    duration = 0
    speed = .normal
  }
}
