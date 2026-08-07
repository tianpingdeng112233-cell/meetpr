import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func removalDuringLegacyCancellationLeaksNoWakeSideEffects() async throws {
  let harness = VideoUploadHarness()
  let record = try await prepareRemovalWakeRace(harness: harness)
  await harness.service.setHasLegacyPendingParts(true)
  await harness.service.suspendNextCancelLegacyParts()

  let finishCounter = await startRemovalWake(recordID: record.id, harness: harness)
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

  let finishCounter = await startRemovalWake(recordID: record.id, harness: harness)
  try await waitUntil { await harness.service.suspendedPendingPartNumbersCount == 1 }
  await harness.manager.remove(attachmentID: record.id)
  await harness.service.releasePendingPartNumbers()
  try await waitUntil { finishCounter.value == 1 }

  try await expectNoLeakedWakeSideEffects(recordID: record.id, harness: harness)
}

@Test func removalDuringManualZombieHarvestDoesNotRestartUpload() async throws {
  let harness = VideoUploadHarness()
  let record = try await prepareRemovalWakeRace(harness: harness)
  await harness.service.setPendingParts([1])
  await harness.service.suspendNextCancelParts()

  let recovery = Task {
    await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  }
  try await waitUntil { await harness.service.suspendedCancelPartsCount == 1 }
  await harness.manager.remove(attachmentID: record.id)
  await harness.service.releaseCancelParts()
  await recovery.value

  try await expectNoLeakedWakeSideEffects(recordID: record.id, harness: harness)
}

@Test func osWakeRegistrationDuringRecoveryWinsBeforeManualHarvest() async throws {
  let harness = VideoUploadHarness()
  let record = try await prepareRemovalWakeRace(harness: harness)
  await harness.service.setPendingParts([1])
  await harness.service.suspendBackgroundWakeCheck(call: 2)

  let recovery = Task {
    await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  }
  try await waitUntil { await harness.service.suspendedBackgroundWakeCheckCount == 1 }
  let counter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }
  await harness.service.releaseBackgroundWakeChecks()
  await recovery.value

  #expect(await harness.service.cancelPartsCount == 0)
  #expect(await harness.manager.activeUploads[record.id] == nil)
  BackgroundUploadCompletionRegistry.shared.markEventsDelivered(
    identifier: harness.service.backgroundSessionIdentifier
  )
  try await waitUntil { counter.value == 1 }
}

@Test func osWakeAfterManualClaimCannotStartASecondWriter() async throws {
  let harness = VideoUploadHarness()
  let record = try await prepareRemovalWakeRace(harness: harness)
  await harness.service.setPendingParts([1])
  await harness.service.suspendNextCancelParts()

  let recovery = Task {
    await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  }
  try await waitUntil { await harness.service.suspendedCancelPartsCount == 1 }

  let counter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }
  await harness.service.finishBackgroundEvents()
  try await waitUntil { counter.value == 1 }
  #expect(await harness.service.calls.allSatisfy { !$0.hasPrefix("schedule:") })

  await harness.service.releaseCancelParts()
  await recovery.value
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(await harness.service.partAttempts[1] == 1)
  #expect(await harness.service.calls.allSatisfy { !$0.hasPrefix("schedule:") })
}

@Test func oldPartAndCancelEventsCannotWakeWriterDuringManualHarvest() async throws {
  let harness = VideoUploadHarness()
  let record = try await prepareRemovalWakeRace(harness: harness)

  // Queue one genuine restored event before harvest so the manual drain has a
  // record to process while cancellation is suspended.
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 1, generation: 1),
      result: .success("etag-1")
    )
  )
  try await waitUntil {
    try await harness.repository.fetch(id: record.id)?.uploadedParts.count == 1
  }
  await harness.service.setPendingParts([1])
  await harness.service.suspendNextCancelParts()

  let recovery = Task {
    await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  }
  try await waitUntil { await harness.service.suspendedCancelPartsCount == 1 }
  let harvestGeneration = try #require(await harness.manager.uploadGenerations[record.id])
  #expect(harvestGeneration > 1)
  #expect(try await harness.repository.fetch(id: record.id)?.uploadGeneration == harvestGeneration)

  // These are the real callbacks produced when cancellation harvests the old
  // URLSession tasks. Both must be acknowledged without persisting or waking
  // a second writer while manual recovery owns the record.
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 1, generation: 1),
      result: .success("late-etag-1")
    )
  )
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 1, generation: 1),
      result: .failure(.cancelled)
    )
  )
  await harness.service.finishBackgroundEvents()
  try await waitUntil {
    await harness.manager.restoredBackgroundRecords[harness.service.backgroundSessionIdentifier]
      == nil
  }
  #expect(
    await harness.service.calls.allSatisfy { call in
      !call.hasPrefix("part:") && !call.hasPrefix("schedule:") && !call.hasPrefix("complete:")
    })

  await harness.service.releaseCancelParts()
  await recovery.value
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(await harness.service.partAttempts[1, default: 0] == 0)
  #expect(await harness.service.calls.filter { $0 == "complete:1" }.count == 1)
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

  await harness.manager.activateBackgroundHandling()
  return record
}

private func startRemovalWake(
  recordID: UUID,
  harness: VideoUploadHarness
) async -> RecoveryLockedCounter {
  let counter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: recordID, partNumber: 1, generation: 1),
      result: .success("etag-1")
    )
  )
  await harness.service.finishBackgroundEvents()
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
