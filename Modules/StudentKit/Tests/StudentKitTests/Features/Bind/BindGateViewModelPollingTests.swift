import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func cancelledPendingPollingDoesNotFetchOrChangeThePage() async {
  let pending = BindFixtures.request(status: .pending)
  let repo = ScriptedBindRepository(mine: [.success(pending)])
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId, bind: repo, stash: StashSpy(),
    isOnboardingComplete: { true }, pollingSleep: { _ in throw CancellationError() }
  )
  await gate.load()
  await gate.pollPendingAcceptance()
  #expect(gate.state == .pendingAcceptance(pending))
  #expect(repo.mineCallCount == 1)
}

@MainActor
@Test func boundGateDoesNotStartPendingPolling() async {
  let accepted = BindFixtures.request(status: .accepted)
  let repo = ScriptedBindRepository(mine: [.success(accepted)])
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId, bind: repo, stash: StashSpy(),
    isOnboardingComplete: { true }, pollingSleep: { _ in Issue.record("Must not start a timer") }
  )
  await gate.load()
  await gate.pollPendingAcceptance()
  #expect(gate.state == .bound(accepted))
  #expect(repo.mineCallCount == 1)
}

@MainActor
@Test func pendingPollingRetriesAfterATransientFailure() async {
  let accepted = BindFixtures.request(status: .accepted)
  let repo = ScriptedBindRepository(mine: [
    .success(BindFixtures.request(status: .pending)),
    .failure(TransportFailure()), .success(accepted),
  ])
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId, bind: repo, stash: StashSpy(),
    isOnboardingComplete: { true }, pollingSleep: { _ in }
  )
  await gate.load()
  await gate.pollPendingAcceptance()
  #expect(gate.state == .bound(accepted))
}

@MainActor
@Test func pendingPollingRefreshesAfterThirtySecondsAndStopsWhenAccepted() async {
  let pending = BindFixtures.request(status: .pending)
  let accepted = BindFixtures.request(status: .accepted)
  let repo = ScriptedBindRepository(mine: [.success(pending), .success(accepted)])
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId, bind: repo, stash: StashSpy(),
    isOnboardingComplete: { true },
    pollingSleep: { interval in
      #expect(interval == .seconds(30))
      #expect(repo.mineCallCount == 1)
    }
  )
  await gate.load()
  await gate.pollPendingAcceptance()
  #expect(gate.state == .bound(accepted))
  #expect(gate.acceptanceRevision == 1)
  #expect(repo.mineCallCount == 2)
}
