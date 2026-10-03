import Testing

@testable import StudentKit

@Suite @MainActor struct SetEntryVideoPlaybackStateTests {
  @Test func playbackStartsPausedAndExpansionPreservesTimeAndSpeed() {
    let state = SetEntryVideoPlaybackState()
    #expect(!state.isPlaying)
    state.updateDuration(90)
    state.seek(to: 27)
    state.setSpeed(.oneAndHalf)
    state.togglePlayback()
    #expect(state.isPlaying)
    #expect(SetEntryVideoPlaybackState.Speed.allCases.map(\.rawValue) == [2, 1.5, 1, 0.5])
    state.toggleExpanded()
    #expect(state.isExpanded)
    #expect(state.handleBack())
    #expect(!state.isExpanded)
    #expect(state.position == 27)
    #expect(state.speed == .oneAndHalf)
    #expect(state.isPlaying)
    #expect(!state.handleBack())
    state.togglePlayback()
    #expect(!state.isPlaying)
    state.seek(to: 200)
    #expect(state.position == 90)
    state.stop()
    #expect(!state.isPlaying)
    #expect(state.position == 0)
  }
}
