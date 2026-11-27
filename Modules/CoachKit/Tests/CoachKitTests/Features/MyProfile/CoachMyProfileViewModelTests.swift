import Foundation
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@Test func coachPrivacyTermsOffersBothDocumentLinks() throws {
  let termsURL = try #require(URL(string: "https://meetpr.app/terms"))
  let privacyURL = try #require(URL(string: "https://meetpr.app/privacy"))
  let inspected = try CoachPrivacyTermsSheet(privacyPolicyURL: privacyURL, termsURL: termsURL)
    .inspect()
  #expect(try inspected.find(link: termsURL).url() == termsURL)
  #expect(try inspected.find(link: privacyURL).url() == privacyURL)
  #expect(throws: (any Error).self) {
    try inspected.find(viewWithAccessibilityIdentifier: "coach.profile.userAgreement.unavailable")
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func coachProfileUsesBackendNameWhenPresent() {
  let viewModel = CoachMyProfileViewModel(
    displayName: "  张教练  ",
    logoutAction: {}
  )

  #expect(viewModel.displayName == "张教练")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test(arguments: [nil, "", "   "])
func coachProfileFallsBackWhenBackendNameIsMissing(_ displayName: String?) {
  let viewModel = CoachMyProfileViewModel(
    displayName: displayName,
    logoutAction: {}
  )

  #expect(viewModel.displayName == CoachMyProfileStrings.fallbackName)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func coachProfileLogoutRunsInjectedAction() async {
  var logoutCount = 0
  let viewModel = CoachMyProfileViewModel {
    logoutCount += 1
  }

  await viewModel.logout()

  #expect(logoutCount == 1)
  #expect(!viewModel.isLoggingOut)
}
