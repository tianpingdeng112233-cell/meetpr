import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func backgroundFailureIsPersistedOnceBeforeHandlerAnd403AbortsOnce() async throws {
  let service = MockVideoUploadService()
  let repository = GatedFailureVideoAttachmentRepository()
  let filesDirectory = FileManager.default.temporaryDirectory
    .appending(path: "background-failure-\(UUID().uuidString)", directoryHint: .isDirectory)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory,
    retryScheduler: UploadRetryScheduler(backoffSeconds: [60], timeBoxSeconds: 1_800)
  )
  let record = try makeFailureRaceRecord(remoteID: service.remoteAttachmentID)
  try await repository.save(record)
  await repository.pauseNextFailureSave()
  await manager.activateBackgroundHandling()
  let counter = FailureRaceCounter()
  BackgroundUploadCompletionRegistry.shared.store(identifier: service.backgroundSessionIdentifier) {
    counter.increment()
  }

  await service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 2, generation: 1),
      result: .failure(.httpStatus(403)),
      hasPipelineContinuation: true
    )
  )
  await service.finishBackgroundEvents()
  try await waitUntil { await repository.failureSaveStarted }
  #expect(counter.value == 0)
  #expect(await service.abortCount == 1)

  await repository.releaseFailureSave()
  try await waitUntil { counter.value == 1 }
  let failed = try #require(await repository.fetch(id: record.id))
  #expect(failed.status == .pending)
  #expect(failed.uploadRetryCount == 1)
  #expect(failed.remoteAttachmentID == nil)
  #expect(await service.abortCount == 1)
}

private func makeFailureRaceRecord(remoteID: UUID) throws -> VideoAttachment {
  let targets = try (1...3).map { partNumber in
    VideoUploadPartTarget(
      partNumber: partNumber,
      url: try #require(URL(string: "https://oss.test/parts/\(partNumber)"))
    )
  }
  return VideoAttachment(
    id: UUID(),
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: remoteID,
    status: .uploading,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 2_560,
    localFileName: "failed.mp4",
    recordedAt: Date(),
    uploadPartCount: 3,
    uploadPartTargets: targets,
    uploadedParts: [VideoUploadedPart(partNumber: 1, etag: "etag-1")],
    uploadGeneration: 1
  )
}

private actor GatedFailureVideoAttachmentRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment] = [:]
  private var pausesFailureSave = false
  private var failureSaveContinuation: CheckedContinuation<Void, Never>?
  private(set) var failureSaveStarted = false

  func pauseNextFailureSave() {
    pausesFailureSave = true
  }

  func releaseFailureSave() {
    failureSaveContinuation?.resume()
    failureSaveContinuation = nil
  }

  func save(_ attachment: VideoAttachment) async throws {
    if pausesFailureSave,
      attachment.status == .pending,
      attachment.uploadRetryCount == 1
    {
      failureSaveStarted = true
      await withCheckedContinuation { continuation in
        failureSaveContinuation = continuation
      }
      pausesFailureSave = false
    }
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

private final class FailureRaceCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  var value: Int { lock.withLock { storage } }

  func increment() {
    lock.withLock { storage += 1 }
  }
}
