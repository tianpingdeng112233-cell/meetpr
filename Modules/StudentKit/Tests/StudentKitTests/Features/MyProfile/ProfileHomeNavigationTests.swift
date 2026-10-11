import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test func profileHomeKeepsIdentityAndSettingsAvailableInEveryState() throws {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let states: [MyProfileViewModel.State] = [.loading, .failed, .empty, .loaded(profile)]
  for state in states {
    var opened: [ProfileMenuDestination] = []
    let view = ProfileHomeContent(
      identity: ProfileIdentity(loginIdentifier: "person@example.com"), state: state,
      isFailed: state == .failed, onOpen: { opened.append($0) }, onRetry: {}, onOneRMInfo: {})
    #expect(try view.inspect().findAll(ProfileIdentityCard.self).count == 1)
    let rows = try view.inspect().findAll(StudentMenuRow.self)
    #expect(rows.count == (state == .empty ? 1 : 5))
    #expect(try rows.last?.actualView().title == StudentStrings.localized(.profileSettings))
    for row in rows { try row.find(ViewType.Button.self).tap() }
    #expect(opened == (state == .empty ? [.settings] : [.about, .health, .meet, .note, .settings]))
    #expect(ProfileMenuDestination.meet.editor == .competition)
    #expect(ProfileMenuDestination.note.editor == .note)
    #expect(ProfileMenuDestination.about.editor == nil)
    #expect(ProfileMenuDestination.health.editor == nil)
  }
}

@MainActor
@Test func profileRefreshFailureKeepsSnapshotAndOffersRetry() async {
  let repository = ProfileRefreshRepository()
  let viewModel = MyProfileViewModel(studentId: StudentDemoSeed.studentID, repo: repository)
  await viewModel.reload()
  let loaded = viewModel.state
  await repository.setFailure(true)
  await viewModel.reload()
  #expect(viewModel.state == loaded)
  #expect(viewModel.isFailed)
  await repository.setFailure(false)
  await viewModel.reload()
  #expect(!viewModel.isFailed)
}

private actor ProfileRefreshRepository: OnboardingRepository {
  var fails = false
  func setFailure(_ value: Bool) { fails = value }
  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    if fails { throw URLError(.notConnectedToInternet) }
    return StudentDemoSeed.makeOnboardingProfile(studentID: studentId)
  }
  func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile {
    StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  }
  func complete() async throws -> OnboardingProfile {
    StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  }
}
