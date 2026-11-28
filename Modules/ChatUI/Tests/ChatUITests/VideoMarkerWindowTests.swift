import CoreModels
import Foundation
import Testing

@testable import ChatUI

@Suite struct VideoMarkerWindowTests {
  @Test func halfOpenWindowFollowsPlaybackTime() {
    let first = marker(at: 1000)
    let second = marker(at: 2000)
    let fractional = marker(at: 1001)
    #expect(VideoMarkerWindow.active(in: [fractional], seconds: 1.001) == fractional)
    #expect(VideoMarkerWindow.active(in: [fractional], seconds: 3.401) == nil)
    let markers = [second, first]
    #expect(VideoMarkerWindow.active(in: [], seconds: 1) == nil)
    #expect(VideoMarkerWindow.active(in: markers, seconds: 0.999) == nil)
    #expect(VideoMarkerWindow.active(in: markers, seconds: 1) == first)
    // A paused playhead gives the same result on every timeline update.
    for _ in 0..<2 {
      #expect(VideoMarkerWindow.active(in: markers, seconds: 1.75) == first)
    }
    #expect(VideoMarkerWindow.active(in: markers, seconds: 2) == second)
    #expect(VideoMarkerWindow.active(in: markers, seconds: 4.399) == second)
    #expect(VideoMarkerWindow.active(in: markers, seconds: 4.4) == nil)
  }

  private func marker(at milliseconds: Int) -> VideoMarker {
    VideoMarker(
      id: UUID(), videoID: UUID(), coachID: UUID(), timeMilliseconds: milliseconds,
      level: .info, note: "cue", createdAt: .now)
  }
}
