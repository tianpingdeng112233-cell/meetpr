import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private final class FakeSkipStore: ReadinessSkipStore, @unchecked Sendable {
  private var skipped: Set<String> = []

  func isSkipped(studentId: UUID, checkinDate: String) -> Bool {
    skipped.contains("\(studentId)|\(checkinDate)")
  }

  func markSkipped(studentId: UUID, checkinDate: String) {
    skipped.insert("\(studentId)|\(checkinDate)")
  }
}

private struct FailingReadinessRepository: ReadinessRepository {
  struct Failure: Error {}
  func submit(_ checkin: ReadinessCheckin) async throws { throw Failure() }
  func fetchCheckin(studentId: UUID, checkinDate: String) async throws -> ReadinessCheckin? {
    nil
  }
}

private let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)  // 2026-01-13 UTC

@MainActor
@Test func gateIsNeededWhenNothingFiledAndNotSkipped() async {
  let viewModel = ReadinessCheckinViewModel(
    repo: InMemoryReadinessRepository(),
    skipStore: FakeSkipStore(),
    now: { frozenNow }
  )
  await viewModel.load(studentId: UUID())
  #expect(viewModel.gate == .needed)
}

@MainActor
@Test func gateIsDoneWhenTodayAlreadyFiled() async {
  let studentId = UUID()
  let viewModel = ReadinessCheckinViewModel(
    repo: InMemoryReadinessRepository(),
    skipStore: FakeSkipStore(),
    now: { frozenNow }
  )
  let submitted = await viewModel.submit(
    ReadinessDraft(sleepQuality: 4, mood: 3, stress: 2, fatigue: [.quad: 3]),
    studentId: studentId
  )
  #expect(submitted)
  guard case .done(let checkin) = viewModel.gate else {
    Issue.record("expected done, got \(viewModel.gate)")
    return
  }
  #expect(checkin.checkinDate == viewModel.todayString)
  #expect(checkin.muscleFatigue == [MuscleFatigue(muscleGroup: .quad, severity: 3)])

  // A fresh VM over the same repo lands on .done straight from load.
  let second = ReadinessCheckinViewModel(
    repo: InMemoryReadinessRepository(seed: [checkin]),
    skipStore: FakeSkipStore(),
    now: { frozenNow }
  )
  await second.load(studentId: studentId)
  #expect(second.gate == .done(checkin))
}

@MainActor
@Test func skipMarksTodayAndSurvivesReload() async {
  let studentId = UUID()
  let skipStore = FakeSkipStore()
  let repo = InMemoryReadinessRepository()
  let viewModel = ReadinessCheckinViewModel(repo: repo, skipStore: skipStore, now: { frozenNow })

  viewModel.skip(studentId: studentId)
  #expect(viewModel.gate == .skippedToday)

  let reloaded = ReadinessCheckinViewModel(repo: repo, skipStore: skipStore, now: { frozenNow })
  await reloaded.load(studentId: studentId)
  #expect(reloaded.gate == .skippedToday, "skip marker persists for the day")

  // Next day the prompt returns: same store, different now.
  let tomorrow = ReadinessCheckinViewModel(
    repo: repo, skipStore: skipStore, now: { frozenNow.addingTimeInterval(86_400) })
  await tomorrow.load(studentId: studentId)
  #expect(tomorrow.gate == .needed)
}

@MainActor
@Test func sameDayResubmissionOverwrites() async {
  let studentId = UUID()
  let repo = InMemoryReadinessRepository()
  let viewModel = ReadinessCheckinViewModel(
    repo: repo, skipStore: FakeSkipStore(), now: { frozenNow })

  _ = await viewModel.submit(
    ReadinessDraft(sleepQuality: 2, mood: 2, stress: 2), studentId: studentId)
  _ = await viewModel.submit(
    ReadinessDraft(sleepQuality: 5, mood: 5, stress: 5, fatigue: [.back: 2]),
    studentId: studentId)

  let stored = try? await repo.fetchCheckin(
    studentId: studentId, checkinDate: viewModel.todayString)
  #expect(stored?.sleepQuality == 5)
  #expect(stored?.muscleFatigue == [MuscleFatigue(muscleGroup: .back, severity: 2)])
}

@MainActor
@Test func failedSubmitKeepsGateNeededWithInlineError() async {
  let viewModel = ReadinessCheckinViewModel(
    repo: FailingReadinessRepository(),
    skipStore: FakeSkipStore(),
    now: { frozenNow }
  )
  await viewModel.load(studentId: UUID())
  let success = await viewModel.submit(
    ReadinessDraft(sleepQuality: 3, mood: 3, stress: 3), studentId: UUID())
  #expect(!success)
  #expect(viewModel.submitError != nil)
  #expect(viewModel.gate == .needed, "failure must not flip the gate")
}

@MainActor
@Test func incompleteStepOneIsRejectedClientSide() async {
  let viewModel = ReadinessCheckinViewModel(
    repo: InMemoryReadinessRepository(),
    skipStore: FakeSkipStore(),
    now: { frozenNow }
  )
  let success = await viewModel.submit(
    ReadinessDraft(sleepQuality: 4, mood: nil, stress: 2), studentId: UUID())
  #expect(!success)
  #expect(viewModel.submitError != nil)
}
