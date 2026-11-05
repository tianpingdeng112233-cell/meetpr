import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct VideoCompletionRuntimeTests {
  @Test func coldBackgroundWakeRestoresSameAccountAndHostReusesTheQueue() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let storage = MemorySetSyncStorage()
    let gate = try WorkoutCompletionGate(studentID: student, storage: storage)
    try gate.request(dayID: day.id)
    try gate.waitForVideos(dayID: day.id, trainingDate: day.scheduledDate, startedAt: Date())
    let harness = VideoUploadHarness()
    let video = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: student, status: .uploaded,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1, localFileName: "ready.mp4",
      recordedAt: Date(), trainingDate: day.scheduledDate)
    try await harness.repository.save(video)
    var creations = 0
    let runtime = StudentSetSyncRuntime(
      identity: { student },
      factory: { id, videos in
        creations += 1
        let queue = try SetSyncQueue(studentID: id, storage: storage) { .planned($0.plannedLog) }
        return StudentSetSyncSession(queue: queue, plans: plans, videos: videos, onLogout: {})
      })
    await harness.manager.installCompletionRecovery { manager in
      await runtime.recover(videos: manager)
    }
    let identifier = "cold-completion-\(UUID())"
    let token = BackgroundUploadCompletionRegistry.shared.beginEvent(identifier: identifier)
    await harness.manager.finishBackgroundSessionEvents(
      identifier: identifier, completionToken: token)
    #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt != nil)
    let foreground = try runtime.session(studentID: student, videos: harness.manager, onLogout: {})
    #expect(foreground.queue.completionGate.pendingDays.isEmpty)
    #expect(creations == 1)
    foreground.stop()
  }

  @Test func anotherAccountCannotResumeOldCompletionIntent() async throws {
    let student = StudentDemoSeed.studentID
    let other = UUID()
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let storage = MemorySetSyncStorage()
    let gate = try WorkoutCompletionGate(studentID: student, storage: storage)
    try gate.request(dayID: day.id)
    try gate.waitForVideos(dayID: day.id, trainingDate: day.scheduledDate, startedAt: Date())
    let harness = VideoUploadHarness()
    let runtime = StudentSetSyncRuntime(
      identity: { other },
      factory: { id, videos in
        let queue = try SetSyncQueue(studentID: id, storage: storage) { .planned($0.plannedLog) }
        return StudentSetSyncSession(queue: queue, plans: plans, videos: videos, onLogout: {})
      })
    await runtime.recover(videos: harness.manager)
    #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt == nil)
    let restored = try WorkoutCompletionGate(studentID: student, storage: storage)
    #expect(restored.pendingDays == [day.id])
    try runtime.session(studentID: other, videos: harness.manager, onLogout: {}).stop()
  }

  @Test func presentationReusesFailureClassificationAndExcludesOtherDays() {
    let date = Date(timeIntervalSince1970: 100)
    func record(_ status: VideoAttachment.Status, pending: Bool = false, other: Bool = false)
      -> VideoAttachment
    {
      var video = VideoAttachment(
        id: UUID(), setLogID: UUID(), studentID: StudentDemoSeed.studentID,
        status: status, contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1,
        localFileName: "clip.mp4", recordedAt: date,
        trainingDate: other ? date.addingTimeInterval(86400) : date)
      if pending { video.pendingDraftID = UUID() }
      return video
    }
    let videos = [
      record(.uploaded), record(.uploading), record(.pending, pending: true),
      record(.failed, other: true),
    ]
    let summary = VideoCompletionPresentation(
      attachments: videos, trainingDate: date, allSetsDone: true, waiting: false)
    #expect(
      summary.total == 3 && summary.done == 1 && summary.failed == 1 && summary.uploading == 1)
    #expect(summary.showsSummary)
    let waiting = VideoCompletionPresentation(
      attachments: videos, trainingDate: date, allSetsDone: false, waiting: true)
    #expect(waiting.waiting && !waiting.showsSummary)
    #expect(waiting.progress == 1.0 / 3.0)
    #expect(
      !VideoCompletionPresentation(
        attachments: [], trainingDate: date, allSetsDone: true, waiting: false
      ).showsSummary)
  }
}
