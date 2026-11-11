import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

/// 2026-11-05 iPhone 12 walkthrough regressions (spec 101 B).
@Suite @MainActor struct OfflineCompletionDeviceRegressionTests {
  /// Airplane mode, every video already delivered: the completion request
  /// fails offline. The reward must stay and completion must go out once the
  /// network returns, instead of the reward being dismissed.
  @Test func offlineCompletionKeepsRewardAndCompletesWhenOnline() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = OfflineTogglePlanRepository(
      base: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])))
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let harness = VideoUploadHarness()
    let session = StudentSetSyncSession(
      queue: queue, plans: plans, videos: harness.manager, onLogout: {})
    let workout = TodayWorkoutViewModel(
      plans: plans, logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
    await workout.load(dayID: day.id, studentID: student)

    plans.offline = true
    queue.start()
    #expect(await workout.completeCurrentDay())
    #expect(workout.completionPhase == .celebration)
    #expect(workout.actionErrorMessage == nil)
    #expect(queue.completionGate.videoWait(dayID: day.id) != nil)
    #expect(try await plans.base.fetchDay(studentID: student, dayID: day.id)?.completedAt == nil)

    plans.offline = false
    await queue.videoCompletion?.refresh()
    #expect(try await plans.base.fetchDay(studentID: student, dayID: day.id)?.completedAt != nil)
    #expect(queue.completionGate.pendingDays.isEmpty)
    session.stop()
  }

  /// Offline camera handoff: no set ID yet is the normal pending path, not a
  /// processing failure, and a failure for one set never shows on another.
  @Test func pendingVideoIsNotAProcessingFailureAndFailuresStayOnTheirSet() async throws {
    let harness = VideoUploadHarness()
    let model = VideoAttachmentViewModel(manager: harness.manager)
    let source = FileManager.default.temporaryDirectory
      .appending(path: "offline-\(UUID().uuidString).mov")
    try Data([0, 1, 2]).write(to: source)
    let draftID = UUID()
    await model.attach(
      sourceURL: source, draftID: draftID, studentID: StudentDemoSeed.studentID,
      trainingDate: Date(), resolveSetLogID: { nil })
    #expect(model.lastErrorMessage == nil)

    let failedDraft = UUID()
    model.reportVideoProcessingFailure(draftID: failedDraft)
    #expect(model.processingFailureMessage(forDraftID: failedDraft) != nil)
    #expect(model.processingFailureMessage(forDraftID: draftID) == nil)
    model.reportVideoProcessingFailure()
    #expect(model.processingFailureMessage(forDraftID: draftID) != nil)
  }
}

/// Wraps the in-memory repository; while `offline`, completion fails like a
/// dropped connection.
private final class OfflineTogglePlanRepository: StudentPlanRepository, @unchecked Sendable {
  let base: InMemoryStudentPlanRepository
  var offline = false

  init(base: InMemoryStudentPlanRepository) { self.base = base }

  func fetchPlan(id: UUID, studentID: UUID) async throws -> StudentPlanView? {
    try await base.fetchPlan(id: id, studentID: studentID)
  }
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    try await base.fetchCurrentPlan(studentID: studentID)
  }
  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    try await base.refreshCurrentPlan(studentID: studentID)
  }
  func fetchDay(studentID: UUID, dayID: UUID) async throws -> StudentPlanDay? {
    if offline { throw URLError(.notConnectedToInternet) }
    return try await base.fetchDay(studentID: studentID, dayID: dayID)
  }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    try await base.fetchCycleDays(studentID: studentID)
  }
  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    if offline { throw URLError(.notConnectedToInternet) }
    return try await base.completeDay(id: id, studentID: studentID)
  }
  func undoDayCompletion(id: UUID, studentID: UUID) async throws {
    try await base.undoDayCompletion(id: id, studentID: studentID)
  }
}
