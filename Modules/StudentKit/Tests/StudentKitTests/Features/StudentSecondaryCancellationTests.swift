import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct StudentSecondaryCancellationTests {
  @Test(arguments: [true, false])
  func growthFamilyCancellationKeepsHistory(urlCancellation: Bool) async {
    let now = Date()
    let point = E1RMHistoryPoint(
      id: UUID(), studentId: StudentDemoSeed.studentID, exerciseId: UUID(), family: .squat,
      setLogId: UUID(), computedAt: now, e1RMKg: 150, sourceWeightKg: 120,
      sourceReps: 5, sourceRPE: 8)
    let repository = ReconciliationSpyE1RMRepository(
      backing: InMemoryE1RMRepository(seedPoints: [point]))
    let model = GrowthCurveViewModel(
      plans: RefreshCatalogRepository(), e1rm: repository, now: { now })
    await model.load(studentID: StudentDemoSeed.studentID)
    let points = model.visiblePoints
    #expect(!points.isEmpty)
    await repository.setFamilyFetchError(
      urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.load(studentID: StudentDemoSeed.studentID)
    #expect(model.state == .loaded)
    #expect(model.visiblePoints == points)
  }

  @Test(arguments: [true, false])
  func historyCatalogCancellationKeepsSnapshot(urlCancellation: Bool) async {
    let plans = RefreshCatalogRepository()
    let model = TrainingHistoryViewModel(plans: plans, logs: InMemoryStudentTrainingLogRepository())
    await model.load(studentID: StudentDemoSeed.studentID)
    let catalog = model.catalog
    #expect(!catalog.isEmpty)
    await plans.setError(urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.load(studentID: StudentDemoSeed.studentID)
    #expect(model.catalog == catalog)
  }

  @Test(arguments: [true, false])
  func weekLogCancellationKeepsPlanMetadata(urlCancellation: Bool) async {
    let initialPlan = StudentDemoSeed.makePlanView()
    let store = TestStudentPlanStore(seed: [StudentDemoSeed.studentID: initialPlan])
    let logs = RefreshWeekLogsRepository()
    let model = WeekOverviewViewModel(
      plans: InMemoryStudentPlanRepository(store: store), logs: logs)
    await model.load(studentID: StudentDemoSeed.studentID)
    let state = model.state
    await store.savePublishedProjection(
      StudentPlanView(
        cycleID: UUID(), weekIndex: 1, startDate: Date(), days: initialPlan.days),
      forStudent: StudentDemoSeed.studentID)
    await logs.setError(urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.load(studentID: StudentDemoSeed.studentID)
    #expect(model.state == state)
    #expect(model.plan == initialPlan)
    #expect(model.planStartDate == initialPlan.startDate)
  }
}

private actor RefreshCatalogRepository: StudentPlanRepository, ExerciseCatalogReading {
  var error: Error?
  func setError(_ error: Error?) { self.error = error }
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { nil }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { [] }
  func fetchExerciseCatalog() async throws -> [Exercise] {
    if let error { throw error }
    return StudentDemoSeed.makePlanView().days.flatMap(\.exercises).map(\.exercise)
  }
}

private actor RefreshWeekLogsRepository: StudentTrainingLogRepository {
  var error: Error?
  func setError(_ error: Error?) { self.error = error }
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog { log }
  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    if let error { throw error }
    return []
  }
  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) async throws -> [StudentSetLog] {
    []
  }
}
