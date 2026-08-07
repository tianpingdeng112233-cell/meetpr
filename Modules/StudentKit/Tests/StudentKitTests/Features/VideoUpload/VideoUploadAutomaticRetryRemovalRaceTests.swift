import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func overlappingRemoveKeepsTheFirstTeardownMarkerUntilDeletionFinishes() async throws {
  let harness = VideoUploadHarness()
  let record = makeAutomaticRetryRaceRecord(status: .uploaded)
  try writeAutomaticRetryRaceFixture(record: record, directory: harness.filesDirectory)
  try await harness.repository.save(record)
  await harness.service.suspendNextCancelParts()

  let firstRemove = Task { await harness.manager.remove(attachmentID: record.id) }
  try await waitUntil { await harness.service.suspendedCancelPartsCount == 1 }
  let overlappingRemove = Task { await harness.manager.remove(attachmentID: record.id) }
  await overlappingRemove.value

  #expect(try await harness.repository.fetch(id: record.id) != nil)
  #expect(await harness.manager.removingRecordIDs.contains(record.id))
  do {
    try await harness.manager.requireLiveWakeContextIfPresent(
      recordID: record.id,
      generation: nil
    )
    Issue.record("nil generation bypassed the live remove marker")
  } catch is CancellationError {
    // nil skips only generation comparison; removal remains authoritative.
  }

  await harness.service.releaseCancelParts()
  await firstRemove.value
  #expect(try await harness.repository.fetch(id: record.id) == nil)
  #expect(await !harness.manager.removingRecordIDs.contains(record.id))
}

@Test func retryTimerCannotRestartARecordRemovedDuringItsFetch() async throws {
  let service = MockVideoUploadService()
  let now = Date(timeIntervalSince1970: 1_775_520_000)
  let record = makeAutomaticRetryRaceRecord(
    status: .pending,
    firstFailureAt: now,
    uploadRetryCount: 1
  )
  let repository = SnapshotGatedVideoAttachmentRepository(seed: record)
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "retry-timer-removal-race-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: directory,
    now: { now },
    retryScheduler: UploadRetryScheduler(backoffSeconds: [0], timeBoxSeconds: 1_800)
  )
  try writeAutomaticRetryRaceFixture(record: record, directory: directory)
  let generation = try #require(await manager.restoreUploadGeneration(from: record))
  await repository.suspendNextFetch()

  let retryTask = try #require(
    await manager.scheduleRetry(
      record: record,
      firstFailureAt: now,
      networkState: .available,
      generation: generation
    )
  )
  try await waitUntil { await repository.fetchStarted }
  await manager.remove(attachmentID: record.id)
  await repository.releaseFetch()
  await retryTask.value

  #expect(await repository.fetch(id: record.id) == nil)
  #expect(await manager.activeUploads[record.id] == nil)
  #expect(await manager.uploadGenerations[record.id] != nil)
  #expect(await service.calls.isEmpty)
}

@Test func terminalFailureCannotResurrectARecordRemovedDuringCancellation() async throws {
  let notifier = RecordingUploadFailureNotifier()
  let harness = VideoUploadHarness(failureNotifier: notifier)
  let record = makeAutomaticRetryRaceRecord(status: .uploading)
  try writeAutomaticRetryRaceFixture(record: record, directory: harness.filesDirectory)
  try await harness.repository.save(record)
  let generation = try #require(await harness.manager.restoreUploadGeneration(from: record))
  await harness.service.suspendNextCancelParts()

  let terminalTask = Task {
    await harness.manager.transitionToTerminalFailure(record, generation: generation)
  }
  try await waitUntil { await harness.service.suspendedCancelPartsCount == 1 }
  await harness.manager.remove(attachmentID: record.id)
  await harness.service.releaseCancelParts()
  await terminalTask.value

  #expect(try await harness.repository.fetch(id: record.id) == nil)
  #expect(await harness.manager.uploadGenerations[record.id] != nil)
  #expect(await notifier.notifiedCounts.isEmpty)
}

@Test func explicitRetryRejectsADeletedHistoricalFetchSnapshot() async throws {
  let service = MockVideoUploadService()
  let record = makeAutomaticRetryRaceRecord(status: .failed)
  let repository = SnapshotGatedVideoAttachmentRepository(seed: record)
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "explicit-retry-deletion-aba-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let manager = makeSnapshotRaceManager(
    service: service,
    repository: repository,
    directory: directory
  )
  try writeAutomaticRetryRaceFixture(record: record, directory: directory)
  let (recorder, collector) = await startEventRecording(manager: manager)
  await repository.suspendNextFetch()

  let retryTask = Task { await manager.retry(attachmentID: record.id) }
  try await waitUntil { await repository.fetchStarted }
  await manager.remove(attachmentID: record.id)
  let tombstone = try #require(await manager.uploadGenerations[record.id])
  let historicalGeneration = try #require(record.uploadGeneration)
  #expect(tombstone > historicalGeneration)

  await repository.releaseFetch()
  await retryTask.value
  try await flushEventRecording(manager: manager, recorder: recorder)
  collector.cancel()
  await collector.value

  try await expectNoSnapshotABALeak(
    recordID: record.id,
    tombstone: tombstone,
    manager: manager,
    service: service,
    recorder: recorder
  )
}

@Test func backgroundWakeRejectsADeletedHistoricalFetchSnapshot() async throws {
  let service = MockVideoUploadService()
  let record = makeAutomaticRetryRaceRecord(status: .uploading)
  let repository = SnapshotGatedVideoAttachmentRepository(seed: record)
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "background-wake-deletion-aba-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let manager = makeSnapshotRaceManager(
    service: service,
    repository: repository,
    directory: directory
  )
  try writeAutomaticRetryRaceFixture(record: record, directory: directory)
  let (recorder, collector) = await startEventRecording(manager: manager)
  await repository.suspendNextFetch()

  let wakeTask = Task { await manager.continueDuringBackgroundWake(recordID: record.id) }
  try await waitUntil { await repository.fetchStarted }
  await manager.remove(attachmentID: record.id)
  let tombstone = try #require(await manager.uploadGenerations[record.id])
  let historicalGeneration = try #require(record.uploadGeneration)
  #expect(tombstone > historicalGeneration)

  await repository.releaseFetch()
  await wakeTask.value
  try await flushEventRecording(manager: manager, recorder: recorder)
  collector.cancel()
  await collector.value

  try await expectNoSnapshotABALeak(
    recordID: record.id,
    tombstone: tombstone,
    manager: manager,
    service: service,
    recorder: recorder
  )
}

private func makeSnapshotRaceManager(
  service: MockVideoUploadService,
  repository: SnapshotGatedVideoAttachmentRepository,
  directory: URL
) -> VideoUploadManager {
  VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: directory
  )
}

private func startEventRecording(
  manager: VideoUploadManager
) async -> (recorder: SnapshotRaceEventRecorder, collector: Task<Void, Never>) {
  let recorder = SnapshotRaceEventRecorder()
  let events = await manager.events()
  let collector = Task {
    for await event in events {
      await recorder.record(event)
    }
  }
  return (recorder, collector)
}

private func flushEventRecording(
  manager: VideoUploadManager,
  recorder: SnapshotRaceEventRecorder
) async throws {
  let barrierID = UUID()
  await manager.broadcast(.removed(setLogID: UUID(), attachmentID: barrierID))
  try await waitUntil { await recorder.removedAttachmentIDs.contains(barrierID) }
}

private func expectNoSnapshotABALeak(
  recordID: UUID,
  tombstone: Int,
  manager: VideoUploadManager,
  service: MockVideoUploadService,
  recorder: SnapshotRaceEventRecorder
) async throws {
  #expect(try await manager.repository.fetch(id: recordID) == nil)
  #expect(await manager.uploadGenerations[recordID] == tombstone)
  let leakedCalls = await service.calls.filter {
    $0.hasPrefix("initiate:") || $0.hasPrefix("schedule:")
  }
  #expect(leakedCalls.isEmpty)
  #expect(await !recorder.updatedAttachmentIDs.contains(recordID))
}

private func makeAutomaticRetryRaceRecord(
  status: VideoAttachment.Status,
  firstFailureAt: Date? = nil,
  uploadRetryCount: Int = 0
) -> VideoAttachment {
  let recordID = UUID()
  return VideoAttachment(
    id: recordID,
    setLogID: UUID(),
    studentID: UUID(),
    status: status,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 1_024,
    localFileName: "\(recordID.uuidString).mp4",
    recordedAt: Date(),
    uploadRetryCount: uploadRetryCount,
    firstUploadFailureAt: firstFailureAt,
    uploadGeneration: 1
  )
}

private func writeAutomaticRetryRaceFixture(
  record: VideoAttachment,
  directory: URL
) throws {
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let fileName = try #require(record.localFileName)
  try Data(repeating: 0xAB, count: 1_024).write(to: directory.appending(path: fileName))
}

private actor SnapshotGatedVideoAttachmentRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment]
  private var suspendsNextFetch = false
  private var fetchContinuation: CheckedContinuation<Void, Never>?
  private(set) var fetchStarted = false

  init(seed: VideoAttachment) {
    storage = [seed.id: seed]
  }

  func suspendNextFetch() {
    suspendsNextFetch = true
  }

  func releaseFetch() {
    fetchContinuation?.resume()
    fetchContinuation = nil
  }

  func save(_ attachment: VideoAttachment) {
    storage[attachment.id] = attachment
  }

  func fetch(id: UUID) async -> VideoAttachment? {
    let snapshot = storage[id]
    if suspendsNextFetch {
      suspendsNextFetch = false
      fetchStarted = true
      await withCheckedContinuation { continuation in
        fetchContinuation = continuation
      }
    }
    return snapshot
  }

  func fetch(setLogID: UUID) -> [VideoAttachment] {
    storage.values.filter { $0.setLogID == setLogID }
  }

  func fetchAll(studentID: UUID) -> [VideoAttachment] {
    storage.values.filter { $0.studentID == studentID }
  }

  func delete(id: UUID) {
    storage[id] = nil
  }

  func playbackURL(for attachment: VideoAttachment) -> URL? {
    nil
  }
}

private actor SnapshotRaceEventRecorder {
  private(set) var updatedAttachmentIDs: Set<UUID> = []
  private(set) var removedAttachmentIDs: Set<UUID> = []

  func record(_ event: VideoUploadEvent) {
    switch event {
    case .updated(let attachment, _):
      updatedAttachmentIDs.insert(attachment.id)
    case .removed(_, let attachmentID):
      removedAttachmentIDs.insert(attachmentID)
    }
  }
}
