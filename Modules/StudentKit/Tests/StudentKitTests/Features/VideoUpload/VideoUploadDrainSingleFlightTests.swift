import Foundation
import Testing

@testable import StudentKit

@Test func overlappingSessionFinishCallbacksShareOneDrainWriter() async throws {
  let harness = VideoUploadHarness()
  let recordID = UUID()
  let fileName = "\(recordID.uuidString).mp4"
  let record = try makeRestoredRecord(
    id: recordID,
    remoteID: harness.service.remoteAttachmentID,
    fileName: fileName
  )
  try writeVideoFixture(fileName: fileName, harness: harness)
  try await harness.repository.save(record)
  await harness.manager.activateBackgroundHandling()
  let counter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }
  await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  BackgroundUploadCompletionRegistry.shared.markEventsDelivered(
    identifier: harness.service.backgroundSessionIdentifier
  )
  try await waitUntil { counter.value == 1 }
  await harness.service.suspendNextPendingPartNumbers()

  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 2, generation: 1),
      result: .success("etag-2")
    )
  )
  try await waitUntil { await harness.service.suspendedPendingPartNumbersCount == 1 }

  let wakeCounter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    wakeCounter.increment()
  }
  await harness.service.finishBackgroundEvents()
  try await Task.sleep(for: .milliseconds(50))
  #expect(await harness.service.pendingPartNumbersCallCount == 1)

  await harness.service.releasePendingPartNumbers()
  try await waitUntil { wakeCounter.value == 1 }
  #expect(await harness.service.pendingPartNumbersCallCount == 1)
  #expect(await harness.service.calls.filter { $0 == "schedule:3" }.count == 1)
}
