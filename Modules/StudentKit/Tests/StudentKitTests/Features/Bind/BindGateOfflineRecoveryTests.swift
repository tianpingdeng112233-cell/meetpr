import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

@Suite @MainActor struct BindGateOfflineRecoveryTests {
  @Test func sameAccountWithTrainingCacheRestoresAcceptedBindingOffline() async throws {
    let suite = "bind-offline-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let accepted = BindFixtures.request(status: .accepted)
    let online = BindGateViewModel(
      studentId: BindFixtures.studentId,
      bind: ScriptedBindRepository(mine: [.success(accepted)]), stash: StashSpy(),
      isOnboardingComplete: { true }, firstRunDefaults: defaults,
      hasCachedTraining: { true })
    await online.load()
    #expect(online.state == .bound(accepted))

    let reopened = BindGateViewModel(
      studentId: BindFixtures.studentId,
      bind: ScriptedBindRepository(mine: [.failure(URLError(.notConnectedToInternet))]),
      stash: StashSpy(), isOnboardingComplete: { true }, firstRunDefaults: defaults,
      hasCachedTraining: { true })
    await reopened.load()
    #expect(reopened.state == .bound(accepted))
    #expect(reopened.acceptanceRevision == 0)
  }
  @Test(arguments: ["no-training", "other-account", "revoked", "unauthorized", "http-error"])
  func offlineRecoveryDoesNotBypassAccountOrServerAuthority(scenario: String) async throws {
    let suite = "bind-offline-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let accepted = BindFixtures.request(status: .accepted)
    let online = BindGateViewModel(
      studentId: BindFixtures.studentId,
      bind: ScriptedBindRepository(mine: [.success(accepted)]), stash: StashSpy(),
      isOnboardingComplete: { true }, firstRunDefaults: defaults, hasCachedTraining: { true })
    await online.load()
    var responses: [ScriptedBindRepository.MineResult] = []
    if scenario == "revoked" { responses.append(.success(nil)) }
    if scenario == "unauthorized" { responses.append(.failure(APIError.authInvalid)) }
    responses.append(
      .failure(
        scenario == "http-error"
          ? APIError.httpStatus(500, Data()) : URLError(.notConnectedToInternet)))
    let gate = BindGateViewModel(
      studentId: scenario == "other-account" ? UUID() : BindFixtures.studentId,
      bind: ScriptedBindRepository(mine: responses), stash: StashSpy(),
      isOnboardingComplete: { true }, firstRunDefaults: defaults,
      hasCachedTraining: { scenario != "no-training" })
    if scenario == "revoked" || scenario == "unauthorized" { await gate.load() }
    await gate.load()
    #expect(gate.state == .failed)
  }

}
