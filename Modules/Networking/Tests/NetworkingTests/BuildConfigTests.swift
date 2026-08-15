import Testing

@testable import Networking

@Test func buildConfigDefaultsToMainlandChinaPhoneValidation() {
  #expect(BuildConfig.phoneValidationStyle(infoDictionary: nil) == .mainlandChina)
  #expect(
    BuildConfig.phoneValidationStyle(infoDictionary: ["MeetPRBuildTrack": "CN"])
      == .mainlandChina
  )
}

@Test func buildConfigSelectsGlobalE164PhoneValidation() {
  #expect(
    BuildConfig.phoneValidationStyle(infoDictionary: ["MeetPRBuildTrack": "Global"])
      == .globalE164
  )
}
