import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func partPersistenceRechecksGenerationAfterItsFetchSuspends() async throws {
  let service = MockVideoUploadService()
  let record = try makeGenerationPersistenceRaceRecord(service: service)
  let repository = PartFetchGatedRepository(seed: record, suspendedFetchCall: 2)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration()
  )
  await manager.activateBackgroundHandling()

  await service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 1, generation: 7),
      result: .success("stale-etag-1")
    )
  )
  try await waitUntil { await repository.fetchSuspended }
  let replacementGeneration = await manager.advanceUploadGeneration(recordID: record.id)
  #expect(replacementGeneration > 7)
  await repository.releaseFetch()

  try await waitUntil {
    await manager.restoredBackgroundRecords[service.backgroundSessionIdentifier] == nil
  }
  let stored = try #require(await repository.fetch(id: record.id))
  #expect(stored.uploadedParts.isEmpty)
  #expect(await manager.uploadGenerations[record.id] == replacementGeneration)
}

@Test func partPersistenceCASRejectsGenerationAdvancedWhileCommitSuspends() async throws {
  let service = MockVideoUploadService()
  let record = try makeGenerationPersistenceRaceRecord(service: service)
  let repository = PartCommitGatedRepository(seed: record)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration()
  )
  _ = await manager.restoreUploadGeneration(from: record)

  let persistence = Task {
    try await manager.persist(
      part: VideoUploadedPart(partNumber: 1, etag: "stale-etag-1"),
      recordID: record.id,
      generation: 7
    )
  }
  try await waitUntil { await repository.partCommitStarted }
  let replacementGeneration = await manager.advanceUploadGeneration(recordID: record.id)
  _ = try await manager.persistUploadGeneration(
    replacementGeneration,
    recordID: record.id
  )
  await repository.releasePartCommit()

  await #expect(throws: CancellationError.self) {
    try await persistence.value
  }
  let stored = try #require(await repository.fetch(id: record.id))
  #expect(stored.uploadGeneration == replacementGeneration)
  #expect(stored.uploadedParts.isEmpty)
}

private actor PartFetchGatedRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment]
  private let suspendedFetchCall: Int
  private var fetchCallCount = 0
  private var fetchContinuation: CheckedContinuation<Void, Never>?
  private(set) var fetchSuspended = false

  init(seed: VideoAttachment, suspendedFetchCall: Int) {
    storage = [seed.id: seed]
    self.suspendedFetchCall = suspendedFetchCall
  }

  func releaseFetch() {
    fetchContinuation?.resume()
    fetchContinuation = nil
  }

  func save(_ attachment: VideoAttachment) {
    storage[attachment.id] = attachment
  }

  func persistUploadedPart(
    _ part: VideoUploadedPart,
    recordID: UUID,
    expectedUploadGeneration: Int
  ) -> VideoAttachment? {
    guard var attachment = storage[recordID],
      attachment.uploadGeneration == expectedUploadGeneration
    else { return nil }
    attachment.uploadedParts.removeAll { $0.partNumber == part.partNumber }
    attachment.uploadedParts.append(part)
    attachment.uploadedParts.sort { $0.partNumber < $1.partNumber }
    storage[recordID] = attachment
    return attachment
  }

  func fetch(id: UUID) async -> VideoAttachment? {
    fetchCallCount += 1
    if fetchCallCount == suspendedFetchCall {
      fetchSuspended = true
      await withCheckedContinuation { continuation in
        fetchContinuation = continuation
      }
    }
    return storage[id]
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

private actor PartCommitGatedRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment]
  private var partCommitContinuation: CheckedContinuation<Void, Never>?
  private(set) var partCommitStarted = false

  init(seed: VideoAttachment) {
    storage = [seed.id: seed]
  }

  func releasePartCommit() {
    partCommitContinuation?.resume()
    partCommitContinuation = nil
  }

  func save(_ attachment: VideoAttachment) {
    storage[attachment.id] = attachment
  }

  func persistUploadedPart(
    _ part: VideoUploadedPart,
    recordID: UUID,
    expectedUploadGeneration: Int
  ) async -> VideoAttachment? {
    partCommitStarted = true
    await withCheckedContinuation { continuation in
      partCommitContinuation = continuation
    }
    guard var attachment = storage[recordID],
      attachment.uploadGeneration == expectedUploadGeneration
    else { return nil }
    attachment.uploadedParts.removeAll { $0.partNumber == part.partNumber }
    attachment.uploadedParts.append(part)
    attachment.uploadedParts.sort { $0.partNumber < $1.partNumber }
    storage[recordID] = attachment
    return attachment
  }

  func fetch(id: UUID) -> VideoAttachment? {
    storage[id]
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
