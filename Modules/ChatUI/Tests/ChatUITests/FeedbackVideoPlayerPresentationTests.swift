import AVFoundation
import Testing

@testable import ChatUI

@MainActor
@Suite("Feedback video workbench player")
struct FeedbackVideoPlayerPresentationTests {
  @Test("workbench uses the four prototype playback rates")
  func workbenchRates() {
    #expect(
      FeedbackVideoPlayerView.workbenchRateText(0.5) == "0.5×"
    )
    #expect(
      FeedbackVideoPlayerView.workbenchRateText(1) == "1×"
    )
    #expect(
      FeedbackVideoPlayerView.workbenchRateText(1.5) == "1.5×"
    )
    #expect(
      FeedbackVideoPlayerView.workbenchRateText(2) == "2×"
    )
  }

  @Test("timeline renders minute and zero-padded second values")
  func timelineText() {
    #expect(FeedbackVideoPlayerView.timeText(7.9) == "0:07")
    #expect(FeedbackVideoPlayerView.timeText(74) == "1:14")
  }

  @Test("default configuration preserves legacy chat and student playback semantics")
  func defaultConfigurationPreservesLegacyPlaybackSemantics() {
    let behavior = FeedbackVideoPlayerView.playbackBehavior(for: nil)

    #expect(behavior == .legacyFullScreen)
    #expect(behavior.appearanceCommand == .play)
    #expect(behavior.retryCommand == .play)
    #expect(behavior.appliesSelectedRate(while: .playing))
    #expect(!behavior.appliesSelectedRate(while: .waitingToPlayAtSpecifiedRate))
    #expect(!behavior.appliesSelectedRate(while: .paused))
  }

  @Test("workbench configuration owns the expanded playback-rate semantics")
  func workbenchConfigurationOwnsExpandedPlaybackSemantics() {
    let behavior = FeedbackVideoPlayerView.playbackBehavior(
      for: FeedbackVideoWorkbenchConfiguration()
    )

    #expect(behavior == .workbench)
    #expect(behavior.appearanceCommand == .none)
    #expect(behavior.retryCommand == .playImmediatelyAtSelectedRate)
    #expect(behavior.appliesSelectedRate(while: .playing))
    #expect(behavior.appliesSelectedRate(while: .waitingToPlayAtSpecifiedRate))
    #expect(!behavior.appliesSelectedRate(while: .paused))
  }

  @Test("marker seek conversion uses millisecond timescale and clamps to duration")
  func markerSeekConversion() {
    let zero = FeedbackVideoPlayerView.seekTime(milliseconds: 0, durationSeconds: 10)
    let negative = FeedbackVideoPlayerView.seekTime(milliseconds: -50, durationSeconds: 10)
    let beyondDuration = FeedbackVideoPlayerView.seekTime(
      milliseconds: 12_345,
      durationSeconds: 4.25
    )

    #expect(zero == CMTime(value: 0, timescale: 1_000))
    #expect(negative == CMTime(value: 0, timescale: 1_000))
    #expect(beyondDuration == CMTime(value: 4_250, timescale: 1_000))
  }

  @Test("scrubber seek conversion clamps invalid and out-of-range positions")
  func scrubberSeekConversion() {
    let midpoint = FeedbackVideoPlayerView.seekTime(seconds: 4.25, durationSeconds: 10)
    let negative = FeedbackVideoPlayerView.seekTime(seconds: -1, durationSeconds: 10)
    let beyondDuration = FeedbackVideoPlayerView.seekTime(seconds: 12, durationSeconds: 10)
    let nonFinite = FeedbackVideoPlayerView.seekTime(
      seconds: .infinity,
      durationSeconds: 10
    )

    #expect(midpoint == CMTime(value: 4_250, timescale: 1_000))
    #expect(negative == .zero)
    #expect(beyondDuration == CMTime(value: 10_000, timescale: 1_000))
    #expect(nonFinite == .zero)
  }

  @Test("scrubbing keeps the drag position isolated from timeline polling")
  func scrubbingKeepsDragPositionStable() {
    var state = FeedbackVideoScrubState()

    state.begin(at: 2, durationSeconds: 10)
    state.move(to: 8, durationSeconds: 10)

    #expect(state.isScrubbing)
    #expect(state.displayedSeconds(currentSeconds: 2.25) == 8)

    state.finish(at: 8, durationSeconds: 10)
    #expect(!state.isScrubbing)
    #expect(state.displayedSeconds(currentSeconds: 8.1) == 8.1)
  }
}
