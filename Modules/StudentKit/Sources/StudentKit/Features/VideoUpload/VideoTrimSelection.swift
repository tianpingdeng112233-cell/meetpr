import Foundation

/// Pure state for a bounded video trim range.
struct VideoTrimSelection: Equatable, Sendable {
  static let minimumDurationSeconds = 0.1

  let sourceDurationSeconds: Double
  let maxDurationSeconds: Double
  private(set) var startSeconds: Double
  private(set) var endSeconds: Double

  init(sourceDurationSeconds: Double, maxDurationSeconds: Double) {
    let duration = max(0, sourceDurationSeconds.isFinite ? sourceDurationSeconds : 0)
    let maximum = max(0, maxDurationSeconds.isFinite ? maxDurationSeconds : 0)
    self.sourceDurationSeconds = duration
    self.maxDurationSeconds = maximum
    startSeconds = 0
    endSeconds = min(duration, maximum)
  }

  var durationSeconds: Double {
    max(0, endSeconds - startSeconds)
  }

  var isValid: Bool {
    durationSeconds > 0 && durationSeconds <= maxDurationSeconds
  }

  /// Dragging a handle past the window's limits pushes the opposite handle
  /// rather than stalling: the grabbed edge always follows the finger while the
  /// window stays within `minimumSelectionDuration...maxDurationSeconds`.
  mutating func moveStart(to proposedSeconds: Double) {
    guard sourceDurationSeconds > 0 else { return }
    let maximumStart = max(0, sourceDurationSeconds - minimumSelectionDuration)
    startSeconds = Self.clamp(proposedSeconds, to: 0...maximumStart)
    if endSeconds - startSeconds < minimumSelectionDuration {
      endSeconds = min(sourceDurationSeconds, startSeconds + minimumSelectionDuration)
      startSeconds = min(startSeconds, max(0, endSeconds - minimumSelectionDuration))
    }
    if endSeconds - startSeconds > maxDurationSeconds {
      endSeconds = min(sourceDurationSeconds, startSeconds + maxDurationSeconds)
    }
  }

  mutating func moveEnd(to proposedSeconds: Double) {
    guard sourceDurationSeconds > 0 else { return }
    let minimumEnd = min(sourceDurationSeconds, minimumSelectionDuration)
    endSeconds = Self.clamp(proposedSeconds, to: minimumEnd...sourceDurationSeconds)
    if endSeconds - startSeconds < minimumSelectionDuration {
      startSeconds = max(0, endSeconds - minimumSelectionDuration)
      let minimumEndAfterPush = min(sourceDurationSeconds, startSeconds + minimumSelectionDuration)
      endSeconds = max(endSeconds, minimumEndAfterPush)
    }
    if endSeconds - startSeconds > maxDurationSeconds {
      startSeconds = max(0, endSeconds - maxDurationSeconds)
    }
  }

  private var minimumSelectionDuration: Double {
    min(Self.minimumDurationSeconds, sourceDurationSeconds)
  }

  private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
    min(max(value, range.lowerBound), range.upperBound)
  }
}
