import DesignSystem
import Foundation
import Networking
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@Test func chinaInvitationActionsPutShareBeforeCopy() throws {
  let actions = CoachInvitationActions(code: "XK7MPQ2RVT", coachName: "Alex", isCopied: false) {}
  let stack = try actions.inspect().vStack()
  _ = try stack.view(CoachInvitationShareLink.self, 0)
  _ = try stack.view(SecondaryButton.self, 1)
}

@MainActor
@Test func profileSharesOnlyOnChinaTrack() async throws {
  let repository = InMemoryInviteCodeRepository(
    seed: InMemoryInviteCodeRepository.demoSeed(coachId: UUID()))
  let codes = InviteCodesViewModel(repository: repository)
  await codes.loadIfNeeded()
  for track in [MeetPRBuildTrack.china, .global] {
    let profile = CoachMyProfileView(
      viewModel: CoachMyProfileViewModel(displayName: "Alex", logoutAction: {}),
      inviteCodes: repository, buildTrack: track, codesViewModel: codes)
    #expect(
      try profile.inspect().findAll(CoachInvitationActions.self).count == (track == .china ? 1 : 0))
  }
}
