import Testing

@testable import CoachKit

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
