import Testing

@testable import StudentKit

@Test("Main video track is the largest enabled track, preserving ties")
func mainVideoTrackSelection() {
  let small = VideoTrackCandidate(isEnabled: true, width: 320, height: 180)
  let large = VideoTrackCandidate(isEnabled: true, width: 640, height: 360)
  let disabled = VideoTrackCandidate(isEnabled: false, width: 1920, height: 1080)
  #expect(VideoMainTrackSelection.index(in: [small]) == 0)
  #expect(VideoMainTrackSelection.index(in: [small, large]) == 1)
  #expect(VideoMainTrackSelection.index(in: [large, large]) == 0)
  #expect(VideoMainTrackSelection.index(in: [disabled, small, large]) == 2)
  #expect(VideoMainTrackSelection.index(in: []) == nil)
  #expect(VideoMainTrackSelection.index(in: [disabled]) == nil)
}
