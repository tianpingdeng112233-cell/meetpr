import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct VideoCompletionIngestionTests {
  @Test func newlySelectedVideoBlocksCompletionBeforeItsLedgerRecordExists() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    try queue.completionGate.request(dayID: day.id)
    try queue.completionGate.waitForVideos(
      dayID: day.id, trainingDate: day.scheduledDate, startedAt: Date())
    let exporter = CompletionGatedExporter()
    let harness = VideoUploadHarness(exporter: exporter)
    let old = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: student, status: .uploaded,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1, localFileName: "old.mp4",
      recordedAt: Date(), trainingDate: day.scheduledDate)
    try await harness.repository.save(old)
    let selection = Task {
      try await harness.manager.enqueue(
        sourceURL: harness.sourceURL, setLogID: old.setLogID,
        studentID: student, trainingDate: day.scheduledDate)
    }
    await exporter.waitForEntry()
    let coordinator = VideoCompletionCoordinator(
      queue: queue, plans: plans, videos: harness.manager)
    await coordinator.refresh()
    #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt == nil)
    #expect(queue.completionGate.pendingDays == [day.id])
    await exporter.release()
    _ = try await selection.value
    coordinator.stop()
  }
}

private actor CompletionGatedExporter: VideoExporting {
  private var entered = false
  private var observers: [CheckedContinuation<Void, Never>] = []
  private var continuation: CheckedContinuation<Void, Never>?
  func durationSeconds(of sourceURL: URL) async throws -> Double {
    entered = true
    for observer in observers { observer.resume() }
    observers = []
    await withCheckedContinuation { continuation = $0 }
    return 1
  }
  func waitForEntry() async {
    if entered { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func release() {
    continuation?.resume()
    continuation = nil
  }
  func export(from sourceURL: URL, to destinationURL: URL) async throws {
    throw MockServiceError.exportFailed
  }
}
