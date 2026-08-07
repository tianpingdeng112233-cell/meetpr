import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func removalDuringLegacyCancellationLeaksNoWakeSideEffects() async throws {
  let harness = VideoUploadHarness()
  let record = try await prepareRemovalWakeRace(harness: harness)
  await harness.service.setHasLegacyPendingParts(true)
  await harness.service.suspendNextCancelLegacyParts()

  let finishCounter = startRemovalWake(harness: harness)
  try await waitUntil { await harness.service.suspendedCancelLegacyPartsCount == 1 }
  await harness.manager.remove(attachmentID: record.id)
  await harness.service.releaseCancelLegacyParts()
  try await waitUntil { finishCounter.value == 1 }

  try await expectNoLeakedWakeSideEffects(recordID: record.id, harness: harness)
}

@Test func removalDuringPendingPartLookupLeaksNoWakeSideEffects() async throws {
  let harness = VideoUploadHarness()
  let record = try await prepareRemovalWakeRace(harness: harness)
  await harness.service.suspendNextPendingPartNumbers()

  let finishCounter = startRemovalWake(harness: harness)
  try await waitUntil { await harness.service.suspendedPendingPartNumbersCount == 1 }
  await harness.manager.remove(attachmentID: record.id)
  await harness.service.releasePendingPartNumbers()
  try await waitUntil { finishCounter.value == 1 }

  try await expectNoLeakedWakeSideEffects(recordID: record.id, harness: harness)
}

private func prepareRemovalWakeRace(
  harness: VideoUploadHarness
) async throws -> VideoAttachment {
  let record = try makeRemovalWakeRaceRecord(harness: harness)
  try FileManager.default.createDirectory(
    at: harness.filesDirectory,
    withIntermediateDirectories: true
  )
  let fileName = try #require(record.localFileName)
  try Data(repeating: 0xAB, count: 1_024).write(
    to: harness.filesDirectory.appending(path: fileName)
  )
  try await harness.repository.save(record)

  // Recovery registration crosses cancelLegacyParts and pendingPartNumbers.
  // An OS-owned pending part keeps that registration pass from starting a
  // writer; clearing it afterwards makes the tested finish wake actionable.
  await harness.service.setPendingParts([1])
  await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  #expect(await harness.manager.activeUploads[record.id] == nil)
  await harness.service.setPendingParts([])
  return record
}

private func startRemovalWake(harness: VideoUploadHarness) -> RecoveryLockedCounter {
  let counter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }
  Task { await harness.service.finishBackgroundEvents() }
  return counter
}

private func expectNoLeakedWakeSideEffects(
  recordID: UUID,
  harness: VideoUploadHarness
) async throws {
  let wakeCalls = await harness.service.calls.filter {
    $0.hasPrefix("initiate:") || $0.hasPrefix("schedule:")
  }
  #expect(wakeCalls.isEmpty)
  #expect(try await harness.repository.fetch(id: recordID) == nil)
}

private func makeRemovalWakeRaceRecord(
  harness: VideoUploadHarness
) throws -> VideoAttachment {
  let recordID = UUID()
  return VideoAttachment(
    id: recordID,
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: harness.service.remoteAttachmentID,
    status: .uploading,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 1_024,
    localFileName: "\(recordID.uuidString).mp4",
    recordedAt: Date(),
    uploadPartCount: 1,
    uploadPartTargets: [
      VideoUploadPartTarget(
        partNumber: 1,
        url: try #require(URL(string: "https://oss.test/parts/1"))
      )
    ],
    uploadGeneration: 1
  )
}
