import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct StudentRefreshCancellationTests {
  @Test(arguments: [true, false])
  func profileCancellationPreservesSnapshotAndErrorFlag(urlCancellation: Bool) async {
    let repository = ScriptedOnboardingRepository()
    repository.fetchResult = OnboardingFixtures.serverProfile()
    let model = MyProfileViewModel(studentId: BindFixtures.studentId, repo: repository)
    await model.reload()
    let state = model.state
    repository.fetchError = cancellation(urlCancellation)
    await model.reload()
    #expect(model.state == state)
    #expect(!model.isFailed)
    let initial = MyProfileViewModel(studentId: BindFixtures.studentId, repo: repository)
    await initial.reload()
    #expect(initial.state == .idle)
    #expect(!initial.isFailed)
    repository.fetchError = URLError(.timedOut)
    await initial.reload()
    #expect(initial.state == .failed)
    #expect(initial.isFailed)
  }

  @Test(arguments: [true, false])
  func pendingBindCancellationPreservesGate(urlCancellation: Bool) async {
    let pending = BindFixtures.request(status: .pending)
    let repository = ScriptedBindRepository(mine: [
      .success(pending), .failure(cancellation(urlCancellation)), .failure(URLError(.timedOut)),
    ])
    let model = BindGateViewModel(
      studentId: BindFixtures.studentId, bind: repository, stash: StashSpy(),
      isOnboardingComplete: { true })
    await model.load()
    await model.refresh()
    #expect(model.state == .pendingAcceptance(pending))
    await model.refresh()
    #expect(model.state == .failed)
  }

  @Test(arguments: [true, false])
  func readinessCancellationKeepsFiledCheckin(urlCancellation: Bool) async {
    let repository = RefreshReadinessRepository()
    let model = ReadinessCheckinViewModel(repo: repository)
    await model.load(studentId: BindFixtures.studentId)
    let gate = model.gate
    if case .done = gate {} else { Issue.record("Expected filed checkin") }
    await repository.setError(cancellation(urlCancellation))
    await model.load(studentId: BindFixtures.studentId)
    #expect(model.gate == gate)
  }

  @Test(arguments: [true, false])
  func progressCancellationKeepsTrainingBaseline(urlCancellation: Bool) async {
    let repository = ScriptedOnboardingRepository()
    repository.fetchResult = OnboardingProfile(
      userId: BindFixtures.studentId, squat1RMKg: 180, bench1RMKg: 120, deadlift1RMKg: 220,
      createdAt: Date(), updatedAt: Date())
    let model = ProgressDataModel(
      studentID: BindFixtures.studentId, plans: RefreshStudentPlanRepository(),
      logs: InMemoryStudentTrainingLogRepository(), e1rm: InMemoryE1RMRepository(),
      onboarding: repository, feedback: nil)
    await model.load()
    #expect(model.isLoaded)
    #expect(model.comparison.trainingTotalKg == 520)
    repository.fetchError = cancellation(urlCancellation)
    await model.load()
    #expect(model.isLoaded)
    #expect(!model.isFailed)
    #expect(model.comparison.trainingTotalKg == 520)
  }

  private func cancellation(_ url: Bool) -> any Error {
    url ? URLError(.cancelled) : CancellationError()
  }
}

private actor RefreshReadinessRepository: ReadinessRepository {
  var error: Error?
  func setError(_ error: Error?) { self.error = error }
  func submit(_ checkin: ReadinessCheckin) async throws {}
  func fetchCheckin(studentId: UUID, checkinDate: String) async throws -> ReadinessCheckin? {
    if let error { throw error }
    return ReadinessCheckin(
      id: UUID(), studentId: studentId, checkinDate: checkinDate,
      sleepQuality: 4, mood: 3, stress: 2, muscleFatigue: [], submittedAt: Date())
  }
}

private struct RefreshStudentPlanRepository: StudentPlanRepository {
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { nil }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { nil }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { [] }
}
