import AVKit

struct FeedbackVideoScrubState: Equatable, Sendable {
  private(set) var isScrubbing = false
  private(set) var positionSeconds = 0.0

  mutating func begin(at currentSeconds: Double, durationSeconds: Double) {
    isScrubbing = true
    positionSeconds = Self.clamped(currentSeconds, durationSeconds: durationSeconds)
  }

  mutating func move(to seconds: Double, durationSeconds: Double) {
    positionSeconds = Self.clamped(seconds, durationSeconds: durationSeconds)
  }

  mutating func finish(at seconds: Double, durationSeconds: Double) {
    positionSeconds = Self.clamped(seconds, durationSeconds: durationSeconds)
    isScrubbing = false
  }

  func displayedSeconds(currentSeconds: Double) -> Double {
    isScrubbing ? positionSeconds : currentSeconds
  }

  private static func clamped(_ seconds: Double, durationSeconds: Double) -> Double {
    let finiteSeconds = seconds.isFinite ? seconds : 0
    let finiteDuration = durationSeconds.isFinite ? durationSeconds : 0
    return min(max(finiteSeconds, 0), max(finiteDuration, 0))
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension FeedbackVideoPlayerView {
  static func rateText(_ rate: Float) -> String {
    switch rate {
    case 0.5: "0.5x"
    case 1.5: "1.5x"
    case 2: "2x"
    default: "1x"
    }
  }

  static func workbenchRateText(_ rate: Float) -> String {
    switch rate {
    case 0.5: "0.5×"
    case 1.5: "1.5×"
    case 2: "2×"
    default: "1×"
    }
  }

  public static func timeText(_ seconds: Double) -> String {
    let totalSeconds = max(0, Int(seconds.rounded(.down)))
    let minutes = totalSeconds / 60
    let remainder = totalSeconds % 60
    let secondText = remainder < 10 ? "0\(remainder)" : "\(remainder)"
    return "\(minutes):\(secondText)"
  }

  static func playbackBehavior(
    for configuration: FeedbackVideoWorkbenchConfiguration?
  ) -> FeedbackVideoPlaybackBehavior {
    configuration == nil ? .legacyFullScreen : .workbench
  }

  static func seekTime(milliseconds: Int, durationSeconds: Double) -> CMTime {
    let nonnegativeMilliseconds = max(0, milliseconds)
    let durationMilliseconds =
      durationSeconds.isFinite && durationSeconds > 0
      ? Int((durationSeconds * 1_000).rounded(.down))
      : nonnegativeMilliseconds
    return CMTime(
      value: CMTimeValue(min(nonnegativeMilliseconds, durationMilliseconds)),
      timescale: 1_000
    )
  }

  static func seekTime(seconds: Double, durationSeconds: Double) -> CMTime {
    let finiteSeconds = seconds.isFinite ? seconds : 0
    let finiteDuration = durationSeconds.isFinite ? durationSeconds : 0
    let clampedSeconds = min(max(finiteSeconds, 0), max(finiteDuration, 0))
    return CMTime(seconds: clampedSeconds, preferredTimescale: 1_000)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
extension FeedbackVideoPlayerView {
  var scrubberPositionSeconds: Double {
    scrubState.displayedSeconds(currentSeconds: currentSeconds)
  }

  func updateTimeline() {
    let current = player.currentTime().seconds
    if !scrubState.isScrubbing, current.isFinite {
      currentSeconds = max(0, current)
      currentSecondsBinding?.wrappedValue = currentSeconds
    }
    let duration = player.currentItem?.duration.seconds ?? 0
    if duration.isFinite {
      durationSeconds = max(0, duration)
    }
  }

  func setScrubbing(_ isScrubbing: Bool) {
    if isScrubbing {
      scrubGeneration += 1
      scrubSeekTask?.cancel()
      scrubSeekTask = nil
      pendingScrubSeconds = nil
      scrubState.begin(at: currentSeconds, durationSeconds: durationSeconds)
      return
    }

    guard scrubState.isScrubbing else { return }
    let targetSeconds = scrubState.positionSeconds
    scrubGeneration += 1
    let generation = scrubGeneration
    scrubSeekTask?.cancel()
    scrubSeekTask = nil
    pendingScrubSeconds = nil
    scrubSeekTask = Task {
      await seekPlayer(
        toSeconds: targetSeconds,
        generation: generation,
        commitsPosition: true
      )
      guard !Task.isCancelled, generation == scrubGeneration else { return }
      scrubState.finish(at: targetSeconds, durationSeconds: durationSeconds)
      updateTimeline()
    }
  }

  func updateScrubberPosition(_ seconds: Double) {
    if !scrubState.isScrubbing {
      scrubState.begin(at: currentSeconds, durationSeconds: durationSeconds)
    }
    scrubState.move(to: seconds, durationSeconds: durationSeconds)
    pendingScrubSeconds = scrubState.positionSeconds
    guard scrubSeekTask == nil else { return }
    let generation = scrubGeneration
    scrubSeekTask = Task {
      while !Task.isCancelled, generation == scrubGeneration {
        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled, generation == scrubGeneration else { break }
        guard let targetSeconds = pendingScrubSeconds else { break }
        pendingScrubSeconds = nil
        await seekPlayer(
          toSeconds: targetSeconds,
          generation: generation,
          commitsPosition: false
        )
      }
      if generation == scrubGeneration {
        scrubSeekTask = nil
      }
    }
  }

  private func seekPlayer(
    toSeconds seconds: Double,
    generation: Int,
    commitsPosition: Bool
  ) async {
    let target = Self.seekTime(
      seconds: seconds,
      durationSeconds: durationSeconds
    )
    let tolerance = CMTime(value: 50, timescale: 1_000)
    _ = await player.seek(
      to: target,
      toleranceBefore: tolerance,
      toleranceAfter: tolerance
    )
    guard !Task.isCancelled, generation == scrubGeneration else { return }
    let targetSeconds = max(0, target.seconds)
    if commitsPosition {
      currentSeconds = targetSeconds
      currentSecondsBinding?.wrappedValue = targetSeconds
    }
    onSeek(Int((targetSeconds * 1_000).rounded()))
  }
}
