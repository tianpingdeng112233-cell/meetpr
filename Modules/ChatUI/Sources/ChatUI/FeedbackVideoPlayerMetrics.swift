import AVKit

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
}
