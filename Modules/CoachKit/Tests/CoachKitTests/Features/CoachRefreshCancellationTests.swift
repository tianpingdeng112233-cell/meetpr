import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

@MainActor
struct CoachRefreshCancellationTests {
  @Test(arguments: [true, false])
  func bindQueueCancellation(urlCancellation: Bool) async {
    let repository = StubBindQueueRepository()
    let model = BindQueueViewModel(repository: repository)
    await repository.setFetchError(cancellation(urlCancellation))
    await model.refresh()
    #expect(model.state == .idle)
    await repository.setFetchError(nil)
    await model.refresh()
    let items = model.items
    #expect(!items.isEmpty)
    await repository.setFetchError(cancellation(urlCancellation))
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.items == items)
  }

  @Test(arguments: [true, false])
  func videoQueueCancellation(urlCancellation: Bool) async {
    let repository = StubVideoQueueRepo(pending: [VideoInboxFixtures.item()])
    let model = CoachVideoQueueViewModel(repository: repository)
    await repository.setCancellationError(cancellation(urlCancellation))
    await model.refresh()
    #expect(model.state == .idle)
    await repository.setCancellationError(nil)
    await model.refresh()
    let items = model.items
    await repository.setCancellationError(cancellation(urlCancellation))
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.items == items)
  }

  @Test(arguments: [true, false])
  func inviteCodesCancellation(urlCancellation: Bool) async {
    let repository = RefreshInviteRepository()
    let model = InviteCodesViewModel(repository: repository)
    await repository.setError(cancellation(urlCancellation))
    await model.reload()
    #expect(model.state == .idle)
    await repository.setError(nil)
    await model.reload()
    let state = model.state
    await repository.setError(cancellation(urlCancellation))
    await model.reload()
    #expect(model.state == state)
  }

  @Test(arguments: [true, false])
  func workspaceCancellation(urlCancellation: Bool) async throws {
    let students = StubCoachPlanRepository(students: [CoachStudentFeatureFixtures.summary()])
    let model = PlanningWorkspaceViewModel(
      repository: students, studentPlans: StubStudentPlanRepository(plans: [:]),
      draftStore: try DraftStore.inMemory())
    await model.refresh()
    let rows = model.needsPlanningRows
    #expect(!rows.isEmpty)
    await students.setError(cancellation(urlCancellation))
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.needsPlanningRows == rows)
    await students.setError(URLError(.timedOut))
    await model.refresh()
    #expect(model.state.isFailure)
  }

  @Test(arguments: [true, false])
  func detailCancellation(urlCancellation: Bool) async {
    let summary = CoachStudentFeatureFixtures.summary()
    let plans = StubStudentPlanRepository(plans: [summary.id: CoachStudentFeatureFixtures.plan()])
    let model = StudentDetailViewModel(
      summary: summary, plans: plans, trainingLogs: StubTrainingLogRepository(logs: []),
      feedback: StubFeedbackRepository())
    await model.refresh()
    let plan = model.plan
    await plans.setFetchError(cancellation(urlCancellation))
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.plan == plan)
    await plans.setFetchError(URLError(.timedOut))
    await model.refresh()
    if case .failed = model.state {} else { Issue.record("Expected genuine failure") }
  }

  @Test(arguments: [true, false])
  func growthCancellation(urlCancellation: Bool) async {
    let repository = RefreshStatsRepository()
    let model = StudentGrowthViewModel(exerciseStats: repository)
    await model.load(studentID: UUID(), now: Date())
    await repository.setError(cancellation(urlCancellation))
    await model.load(studentID: UUID(), now: Date())
    #expect(model.state == .loaded)
    await repository.setError(URLError(.timedOut))
    await model.load(studentID: UUID(), now: Date())
    if case .failed = model.state {} else { Issue.record("Expected genuine failure") }
  }

  private func cancellation(_ url: Bool) -> any Error {
    url ? URLError(.cancelled) : CancellationError()
  }
}

extension StubVideoQueueRepo {
  func setCancellationError(_ error: Error?) { fetchError = error }
}

private actor RefreshInviteRepository: InviteCodeRepository {
  var error: Error?
  func setError(_ error: Error?) { self.error = error }
  func listCodes() async throws -> [InviteCode] {
    if let error { throw error }
    return InMemoryInviteCodeRepository.demoSeed(coachId: UUID(), now: Date())
  }
  func createCode(type: InviteCodeType, label: String?, expiresInDays: Int?) async throws
    -> InviteCode
  { throw URLError(.unsupportedURL) }
  func revokeCode(id: UUID) async throws {}
}

private actor RefreshStatsRepository: CoachExerciseStatsProviding {
  var error: Error?
  func setError(_ error: Error?) { self.error = error }
  func fetchExerciseStats(studentID: UUID) async throws -> CoachExerciseStatsSnapshot {
    if let error { throw error }
    return CoachExerciseStatsSnapshot()
  }
}
