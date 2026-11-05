import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Suite @MainActor struct VideoCompletionBoundaryTests {
  @Test func currentGroupEditsMustDrainBeforeDeliveredVideosCompleteExactlyOnce() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = VideoCompletionCountingPlans(plan: plan, studentID: student)
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    try queue.completionGate.request(dayID: day.id)
    try queue.completionGate.waitForVideos(
      dayID: day.id, trainingDate: day.scheduledDate, startedAt: Date())
    try queue.enqueue(
      dayID: day.id, trainingDate: day.scheduledDate, draft: SetSyncQueueTests.draft())
    let harness = VideoUploadHarness()
    let coordinator = VideoCompletionCoordinator(
      queue: queue, plans: plans, videos: harness.manager)
    await coordinator.refresh()
    #expect(await plans.calls == 0)
    #expect(queue.completionGate.pendingDays == [day.id])
    await queue.drain()
    await coordinator.refresh()
    await coordinator.refresh()
    #expect(await plans.calls == 1)
    #expect(queue.completionGate.pendingDays.isEmpty)
  }

  @Test func ledgerReadFailureCannotBeMistakenForACompletedVideoDay() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = VideoCompletionCountingPlans(plan: plan, studentID: student)
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let videos = VideoUploadManager(
      service: LoopbackVideoUploadService(), exporter: MockVideoExporter(),
      repository: UnreadableCompletionVideoRepository())
    let session = StudentSetSyncSession(queue: queue, plans: plans, videos: videos, onLogout: {})
    let workout = TodayWorkoutViewModel(
      plans: plans, logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
    await workout.load(dayID: day.id, studentID: student)
    #expect(!(await workout.completeCurrentDay()))
    #expect(workout.completionPhase == nil)
    #expect(await plans.calls == 0)
    session.stop()
  }
}

private actor VideoCompletionCountingPlans: StudentPlanRepository {
  let base: InMemoryStudentPlanRepository
  var calls = 0
  init(plan: StudentPlanView, studentID: UUID) {
    base = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan]))
  }
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    try await base.fetchCurrentPlan(studentID: studentID)
  }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    try await base.fetchCycleDays(studentID: studentID)
  }
  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    calls += 1
    return try await base.completeDay(id: id, studentID: studentID)
  }
}

private struct UnreadableCompletionVideoRepository: VideoAttachmentRepository {
  func save(_ attachment: VideoAttachment) async throws {}
  func persistUploadedPart(_ part: VideoUploadedPart, recordID: UUID, expectedUploadGeneration: Int)
    async throws -> VideoAttachment?
  { nil }
  func fetch(id: UUID) async throws -> VideoAttachment? { nil }
  func fetch(setLogID: UUID) async throws -> [VideoAttachment] { [] }
  func fetchAll(studentID: UUID) async throws -> [VideoAttachment] {
    throw CocoaError(.fileReadCorruptFile)
  }
  func delete(id: UUID) async throws {}
  func playbackURL(for attachment: VideoAttachment) async throws -> URL? { nil }
}
