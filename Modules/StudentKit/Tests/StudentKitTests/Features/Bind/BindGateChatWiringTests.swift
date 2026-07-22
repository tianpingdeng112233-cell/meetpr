import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func activeCoachContextUsesBindNameAndChineseFallback() {
  let named = ActiveCoachContext(
    bindRequest: BindFixtures.request(status: .accepted, coachDisplayName: "周教练")
  )
  let fallback = ActiveCoachContext(
    bindRequest: BindFixtures.request(status: .accepted, coachDisplayName: nil)
  )

  #expect(named.coachID == BindFixtures.coachId)
  #expect(named.coachDisplayName == "周教练")
  #expect(fallback.coachDisplayName == "教练")
}

@MainActor
@Test func refreshingSameCoachDoesNotRunChatCleanup() async {
  let accepted = BindFixtures.request(status: .accepted)
  var cleanupCount = 0
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: ScriptedBindRepository(mine: [.success(accepted), .success(accepted)]),
    stash: StashSpy(),
    isOnboardingComplete: { true },
    willApplyBindingChange: { _, _ in cleanupCount += 1 }
  )

  await gate.load()
  cleanupCount = 0
  await gate.refresh()

  #expect(cleanupCount == 0)
  #expect(gate.state == .bound(accepted))
}

@MainActor
@Test func coachChangeWaitsForCleanupBeforePublishingNewContext() async throws {
  let old = BindFixtures.request(status: .accepted)
  let newCoachID = UUID()
  let replacement = BindFixtures.request(
    status: .accepted,
    coachId: newCoachID,
    coachDisplayName: "新教练"
  )
  let cleanupStarted = AsyncStream<Void>.makeStream()
  let cleanupRelease = AsyncStream<Void>.makeStream()
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: ScriptedBindRepository(mine: [.success(old), .success(replacement)]),
    stash: StashSpy(),
    isOnboardingComplete: { true },
    willApplyBindingChange: { oldCoachID, _ in
      guard oldCoachID != nil else { return }
      cleanupStarted.continuation.yield()
      for await _ in cleanupRelease.stream {
        break
      }
    }
  )
  await gate.load()

  let refreshTask = Task { await gate.refresh() }
  for await _ in cleanupStarted.stream {
    break
  }

  #expect(gate.state == .bound(old))
  cleanupRelease.continuation.yield()
  await refreshTask.value
  #expect(gate.state == .bound(replacement))
}

@MainActor
@Test func unbindRunsCleanupBeforeRemovingActiveCoach() async {
  let accepted = BindFixtures.request(status: .accepted)
  var cleanupTransitions: [(UUID?, UUID?)] = []
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: ScriptedBindRepository(mine: [.success(accepted), .success(nil)]),
    stash: StashSpy(),
    isOnboardingComplete: { true },
    willApplyBindingChange: { oldCoachID, newCoachID in
      cleanupTransitions.append((oldCoachID, newCoachID))
    }
  )

  await gate.load()
  cleanupTransitions.removeAll()
  await gate.refresh()

  #expect(cleanupTransitions.count == 1)
  #expect(cleanupTransitions.first?.0 == accepted.coachId)
  #expect(cleanupTransitions.first?.1 == nil)
  #expect(gate.state == .needsCode(prefillDisplayName: nil, notice: nil))
}
