import Testing

@testable import Networking

@Test func buildConfigDefaultsToChinaTrack() {
  #expect(BuildConfig.buildTrack(infoDictionary: nil) == .china)
  #expect(BuildConfig.buildTrack(infoDictionary: ["MeetPRBuildTrack": "CN"]) == .china)
}

@Test func buildConfigSelectsGlobalTrack() {
  #expect(BuildConfig.buildTrack(infoDictionary: ["MeetPRBuildTrack": "Global"]) == .global)
}
