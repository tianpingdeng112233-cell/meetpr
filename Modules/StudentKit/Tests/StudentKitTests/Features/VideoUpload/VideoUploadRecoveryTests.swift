import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func terminalFailureRemovesChunkFilesButKeepsRetryableVideo() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setPartFailures([1: 6])
  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )

  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])

  #expect(
    FileManager.default.fileExists(
      atPath: harness.filesDirectory.appending(path: "\(record.id.uuidString).mp4").path
    )
  )
  #expect(
    !FileManager.default.fileExists(
      atPath: harness.filesDirectory.appending(path: "\(record.id.uuidString).parts").path
    )
  )
}

@Test func expiredOSSSignatureAbortsAndReinitiatesWholeUpload() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setSignatureFailures([1: 1])

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])

  let initiateCalls = await harness.service.calls.filter { $0.hasPrefix("initiate:") }
  #expect(initiateCalls.count == 2)
  #expect(await harness.service.abortCount == 1)
}

@Test func restoredBackgroundEventsPersistETagsThenSendComplete() async throws {
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
  await harness.service.setPendingParts([3])

  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: recordID, partNumber: 2),
      result: .success("etag-2")
    )
  )
  try await waitUntil {
    try await harness.repository.fetch(id: recordID)?.uploadedParts.count == 2
  }
  #expect(try await harness.repository.fetch(id: recordID)?.status == .uploading)

  await harness.service.setPendingParts([])
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: recordID, partNumber: 3),
      result: .success("etag-3")
    )
  )
  await harness.service.finishBackgroundEvents()

  _ = try await waitForStatus(harness.repository, id: recordID, oneOf: [.uploaded])
  #expect(await harness.service.calls.contains("complete:1,2,3"))
}

@Test func deterministic4xxFailsOnceAndSendsAggregatedNotification() async throws {
  let notifier = RecordingUploadFailureNotifier()
  let harness = VideoUploadHarness(failureNotifier: notifier)
  await harness.service.setDeterministicFailures([1: 1])

  let trainingDate = Date(timeIntervalSince1970: 1_775_520_000)
  let setLogID = UUID()
  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: setLogID,
    studentID: UUID(),
    trainingDate: trainingDate
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])

  #expect(await harness.service.partAttempts[1] == 1)
  #expect(await notifier.authorizationRequestCount == 1)
  #expect(await notifier.notifiedCounts == [1])
  #expect(
    await notifier.destinations == [
      UploadFailureDestination(setLogID: setLogID, trainingDate: trainingDate)
    ]
  )
}

@Test func restoredBackgroundBatchDoesNotReuploadPartsWhoseCallbacksWereQueued() async throws {
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

  for partNumber in 2...3 {
    await harness.service.emitBackgroundEvent(
      BackgroundVideoPartEvent(
        identifier: VideoUploadPartIdentifier(recordID: recordID, partNumber: partNumber),
        result: .success("etag-\(partNumber)")
      )
    )
  }
  await harness.service.finishBackgroundEvents()

  _ = try await waitForStatus(harness.repository, id: recordID, oneOf: [.uploaded])
  let calls = await harness.service.calls
  #expect(calls == ["complete:1,2,3"])
}

@Test func transientFailurePreservesSessionAndCompletedETags() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setPartFailures([2: 1])

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])

  let calls = await harness.service.calls
  #expect(calls.filter { $0 == "part:1" }.count == 1)
  #expect(calls.filter { $0.hasPrefix("initiate:") }.count == 1)
  #expect(await harness.service.abortCount == 0)
}

@Test func failedAbortRemainsQueuedAfterLocalDeletionAndRetriesOnRecovery() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setHangOnParts(true)
  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  try await waitUntil {
    try await harness.repository.fetch(id: record.id)?.remoteAttachmentID != nil
  }
  await harness.service.setAbortFailures(1)

  await harness.manager.remove(attachmentID: record.id)

  let cleanupFile = harness.filesDirectory.appending(path: "pending-remote-cleanup.json")
  let restartedStore = RemoteAttachmentCleanupStore(fileURL: cleanupFile)
  #expect(
    try await restartedStore.pendingAttachmentIDs()
      == Set([harness.service.remoteAttachmentID])
  )
  let restartedManager = VideoUploadManager(
    service: harness.service,
    exporter: MockVideoExporter(),
    repository: harness.repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: harness.filesDirectory,
    retryScheduler: UploadRetryScheduler(backoffSeconds: [0], timeBoxSeconds: 1_800),
    cleanupStore: restartedStore
  )
  await restartedManager.recoverInterruptedUploads(studentID: record.studentID)
  #expect(try await restartedStore.pendingAttachmentIDs().isEmpty)
  #expect(await harness.service.abortCount == 2)
}

@Test func backgroundCompletionWaitsForRestoredETagPersistenceAndComplete() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setCompleteDelay(.milliseconds(200))
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

  for partNumber in 2...3 {
    await harness.service.emitBackgroundEvent(
      BackgroundVideoPartEvent(
        identifier: VideoUploadPartIdentifier(recordID: recordID, partNumber: partNumber),
        result: .success("etag-\(partNumber)")
      )
    )
  }
  await harness.service.finishBackgroundEvents()
  try await Task.sleep(for: .milliseconds(50))
  #expect(counter.value == 0)

  _ = try await waitForStatus(harness.repository, id: recordID, oneOf: [.uploaded])
  try await waitUntil { counter.value == 1 }
  #expect(counter.value == 1)
}

@Test func backgroundWakeSchedulesOnlyNextBatchThenReleasesHandler() async throws {
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
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 2),
      result: .success("etag-2")
    )
  )
  await harness.service.finishBackgroundEvents()
  try await waitUntil { counter.value == 1 }

  let stored = try #require(try await harness.repository.fetch(id: record.id))
  #expect(stored.status == .uploading)
  #expect(stored.uploadedParts.map(\.partNumber) == [1, 2])
  #expect(await harness.service.calls == ["schedule:3"])
}

@Test func backgroundWakePlannerCompletesOnlyWhenEveryETagExists() {
  let planner = BackgroundUploadWakePlanner()

  #expect(
    planner.decision(
      partCount: 3,
      targetPartNumbers: [1, 2, 3],
      completedPartNumbers: [1, 2, 3],
      pendingPartNumbers: [],
      maxConcurrentParts: 2
    ) == .complete
  )
}

@Test func backgroundWakePlannerFillsOnlyAvailableBackgroundTaskSlots() {
  let planner = BackgroundUploadWakePlanner()

  #expect(
    planner.decision(
      partCount: 4,
      targetPartNumbers: [1, 2, 3, 4],
      completedPartNumbers: [1],
      pendingPartNumbers: [2],
      maxConcurrentParts: 2
    ) == .scheduleParts([3])
  )
  #expect(
    planner.decision(
      partCount: 4,
      targetPartNumbers: [1, 2, 3, 4],
      completedPartNumbers: [1],
      pendingPartNumbers: [2, 3],
      maxConcurrentParts: 2
    ) == .waitForScheduledParts
  )
}

@Test func backgroundWakePlannerRequestsPreparationForMissingRemoteMetadata() {
  let decision = BackgroundUploadWakePlanner().decision(
    partCount: 0,
    targetPartNumbers: [],
    completedPartNumbers: [],
    pendingPartNumbers: [],
    maxConcurrentParts: 3
  )

  #expect(decision == .prepareRemoteSession)
}

@Test func emptyRestoredBatchStillCompletesPersistedPipelineBeforeOSHandler() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setCompleteDelay(.milliseconds(200))
  let recordID = UUID()
  let fileName = "\(recordID.uuidString).mp4"
  var record = try makeRestoredRecord(
    id: recordID,
    remoteID: harness.service.remoteAttachmentID,
    fileName: fileName
  )
  record.uploadedParts = [
    VideoUploadedPart(partNumber: 1, etag: "etag-1"),
    VideoUploadedPart(partNumber: 2, etag: "etag-2"),
    VideoUploadedPart(partNumber: 3, etag: "etag-3"),
  ]
  try writeVideoFixture(fileName: fileName, harness: harness)
  try await harness.repository.save(record)
  let counter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }

  await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  await harness.service.finishBackgroundEvents()
  try await Task.sleep(for: .milliseconds(50))
  #expect(counter.value == 0)

  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  try await waitUntil { counter.value == 1 }
}

private func makeRestoredRecord(id: UUID, remoteID: UUID, fileName: String) throws
  -> VideoAttachment
{
  let targets = try (1...3).map { partNumber in
    VideoUploadPartTarget(
      partNumber: partNumber,
      url: try #require(URL(string: "https://oss.test/parts/\(partNumber)"))
    )
  }
  return VideoAttachment(
    id: id,
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: remoteID,
    status: .uploading,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 2_560,
    localFileName: fileName,
    recordedAt: Date(),
    uploadPartCount: 3,
    uploadPartTargets: targets,
    uploadedParts: [VideoUploadedPart(partNumber: 1, etag: "etag-1")]
  )
}

private func writeVideoFixture(fileName: String, harness: VideoUploadHarness) throws {
  try FileManager.default.createDirectory(
    at: harness.filesDirectory,
    withIntermediateDirectories: true
  )
  try Data(repeating: 0xAB, count: 2_560).write(
    to: harness.filesDirectory.appending(path: fileName)
  )
}

private final class RecoveryLockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  var value: Int { lock.withLock { storage } }

  func increment() {
    lock.withLock { storage += 1 }
  }
}
