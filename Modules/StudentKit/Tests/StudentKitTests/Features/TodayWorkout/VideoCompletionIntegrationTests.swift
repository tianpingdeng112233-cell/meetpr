import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct VideoCompletionIntegrationTests {
  @Test func rewardAppearsButCompletionWaitsForVideo() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let harness = VideoUploadHarness()
    let record = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: student, status: .pending,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1,
      localFileName: "waiting.mp4", recordedAt: Date(), trainingDate: day.scheduledDate)
    try await harness.repository.save(record)
    let session = StudentSetSyncSession(
      queue: queue, plans: plans, videos: harness.manager, onLogout: {})
    let workout = TodayWorkoutViewModel(
      plans: plans, logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
    await workout.load(dayID: day.id, studentID: student)
    #expect(await workout.completeCurrentDay())
    #expect(workout.completionPhase == .celebration)
    #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt == nil)
    #expect(queue.completionGate.pendingDays == [day.id])
    session.stop()
  }
  @Test func restoredWaitUsesCurrentVideosAndCompletesOnce() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let storage = MemorySetSyncStorage()
    let original = try WorkoutCompletionGate(studentID: student, storage: storage)
    try original.request(dayID: day.id)
    try original.waitForVideos(dayID: day.id, trainingDate: day.scheduledDate, startedAt: Date())
    let queue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    let harness = VideoUploadHarness()
    var video = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: student, status: .pending,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1,
      localFileName: "waiting.mp4", recordedAt: Date(), trainingDate: day.scheduledDate)
    try await harness.repository.save(video)
    let coordinator = VideoCompletionCoordinator(
      queue: queue, plans: plans, videos: harness.manager)
    await coordinator.refresh()
    #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt == nil)
    video.status = .uploaded
    try await harness.repository.save(video)
    var replacement = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: student, status: .pending,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1,
      localFileName: "new.mp4", recordedAt: Date(), trainingDate: day.scheduledDate)
    try await harness.repository.save(replacement)
    await coordinator.refresh()
    #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt == nil)
    replacement.status = .uploaded
    try await harness.repository.save(replacement)
    await coordinator.refresh()
    #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt != nil)
    #expect(queue.completionGate.pendingDays.isEmpty)
  }

  @Test func backgroundDrainAwaitsCompletionRecoveryBeforeAcknowledgingOS() async throws {
    let harness = VideoUploadHarness()
    let calls = RecoveryLockedCounter()
    await harness.manager.installCompletionRecovery { _ in
      await Task.yield()
      calls.increment()
    }
    let identifier = "completion-drain-\(UUID())"
    let registry = BackgroundUploadCompletionRegistry.shared
    let token = registry.beginEvent(identifier: identifier)
    let acknowledgments = RecoveryLockedCounter()
    registry.store(identifier: identifier) {
      #expect(calls.value == 1)
      acknowledgments.increment()
    }
    registry.markEventsDelivered(identifier: identifier)
    await harness.manager.finishBackgroundSessionEvents(
      identifier: identifier, completionToken: token)
    try await waitForSetSync { acknowledgments.value == 1 }
    #expect(calls.value == 1)
  }

  @Test func timeoutAndCompletionSurviveRestartWithoutRepeatedNotifications() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let storage = MemorySetSyncStorage()
    let started = Date(timeIntervalSince1970: 100)
    let queue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    try queue.completionGate.request(dayID: day.id)
    try queue.completionGate.waitForVideos(
      dayID: day.id, trainingDate: day.scheduledDate, startedAt: started)
    let notifier = CompletionNotificationSpy()
    let repository = InMemoryVideoAttachmentRepository()
    let manager = VideoUploadManager(
      service: LoopbackVideoUploadService(), exporter: AVFoundationVideoExporter(),
      repository: repository, now: { started.addingTimeInterval(1801) }, failureNotifier: notifier)
    var video = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: student, status: .pending,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1, localFileName: "wait.mp4",
      recordedAt: started, trainingDate: day.scheduledDate)
    try await repository.save(video)
    let first = VideoCompletionCoordinator(queue: queue, plans: plans, videos: manager)
    await first.refresh()
    await first.refresh()
    #expect(await notifier.timeouts == 1)
    #expect(queue.completionGate.pendingDays == [day.id])
    first.stop()
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    let second = VideoCompletionCoordinator(queue: restored, plans: plans, videos: manager)
    await second.refresh()
    #expect(await notifier.timeouts == 1)
    video.status = .uploaded
    try await repository.save(video)
    await second.refresh()
    await second.refresh()
    #expect(await notifier.completions == 1)
    #expect(restored.completionGate.pendingDays.isEmpty)
  }

}

private actor CompletionNotificationSpy: UploadFailureNotifying {
  var timeouts = 0
  var completions = 0
  func requestAuthorization() async {}
  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async {}
  func scheduleCompletionTimeout(count: Int, deadline: Date, destination: UploadFailureDestination)
    async
  { timeouts += 1 }
  func notifyWorkoutCompleted(count: Int, destination: UploadFailureDestination) async {
    completions += 1
  }
}
