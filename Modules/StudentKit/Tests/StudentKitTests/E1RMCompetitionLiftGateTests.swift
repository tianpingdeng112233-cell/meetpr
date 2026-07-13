import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func competitionLiftGateFailureNeverBecomesReadyAndCanRetry() async {
  let migration = SequencedCompetitionLiftMigration(failuresRemaining: 1)
  let viewModel = E1RMCompetitionLiftGateViewModel(migration: migration)
  let studentID = UUID()

  await viewModel.migrate(studentID: studentID)
  #expect(viewModel.state == .failed)
  #expect(await migration.callCount == 1)

  await viewModel.migrate(studentID: studentID)
  #expect(viewModel.state == .ready)
  #expect(await migration.callCount == 2)
}

@MainActor
@Test func competitionLiftGateRunsOnlyOnceAfterReady() async {
  let migration = SequencedCompetitionLiftMigration()
  let viewModel = E1RMCompetitionLiftGateViewModel(migration: migration)

  await viewModel.migrate(studentID: UUID())
  await viewModel.migrate(studentID: UUID())

  #expect(viewModel.state == .ready)
  #expect(await migration.callCount == 1)
}

private actor SequencedCompetitionLiftMigration: E1RMCompetitionLiftRunning {
  private(set) var callCount = 0
  private var failuresRemaining: Int

  init(failuresRemaining: Int = 0) {
    self.failuresRemaining = failuresRemaining
  }

  func runIfNeeded(studentID: UUID) async throws -> E1RMCompetitionLiftMigration.Result {
    callCount += 1
    if failuresRemaining > 0 {
      failuresRemaining -= 1
      throw CompetitionLiftGateTestError()
    }
    return .init(didRun: true, pointCount: 0)
  }
}

private struct CompetitionLiftGateTestError: Error {}
