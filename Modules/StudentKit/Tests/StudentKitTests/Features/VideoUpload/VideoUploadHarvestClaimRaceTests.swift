import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func handlerRegistrationDuringGenerationCommitCannotRevokeManualClaim() async throws {
  let service = MockVideoUploadService()
  let record = try makeHarvestClaimRecord(service: service)
  let repository = HarvestGenerationGatedRepository(seed: record)
  let filesDirectory = FileManager.default.temporaryDirectory.appending(
    path: "video-upload-harvest-claim-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  try writeHarvestClaimFixture(record: record, filesDirectory: filesDirectory)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory
  )
  await service.setPendingParts([1])

  let recovery = Task {
    await manager.recoverInterruptedUploads(studentID: record.studentID)
  }
  try await waitUntil { await repository.generationCommitStarted }
  #expect(await service.backgroundCancellationClaim != nil)

  let handlerCounter = RecoveryLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: service.backgroundSessionIdentifier
  ) {
    handlerCounter.increment()
  }
  await repository.releaseGenerationCommit()
  await recovery.value

  _ = try await waitForStatus(repository, id: record.id, oneOf: [.uploaded])
  #expect(await service.cancelPartsCount == 1)
  #expect(await service.backgroundCancellationClaim == nil)
  BackgroundUploadCompletionRegistry.shared.markEventsDelivered(
    identifier: service.backgroundSessionIdentifier
  )
  try await waitUntil { handlerCounter.value == 1 }
}

private func makeHarvestClaimRecord(service: MockVideoUploadService) throws -> VideoAttachment {
  let recordID = UUID()
  return VideoAttachment(
    id: recordID,
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: service.remoteAttachmentID,
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

private func writeHarvestClaimFixture(
  record: VideoAttachment,
  filesDirectory: URL
) throws {
  try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
  let fileName = try #require(record.localFileName)
  try Data(repeating: 0xAB, count: 1_024).write(to: filesDirectory.appending(path: fileName))
}

private actor HarvestGenerationGatedRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment]
  private var generationCommitContinuation: CheckedContinuation<Void, Never>?
  private var shouldSuspendGenerationCommit = true
  private(set) var generationCommitStarted = false

  init(seed: VideoAttachment) {
    storage = [seed.id: seed]
  }

  func releaseGenerationCommit() {
    generationCommitContinuation?.resume()
    generationCommitContinuation = nil
  }

  func save(_ attachment: VideoAttachment) async {
    if shouldSuspendGenerationCommit,
      attachment.uploadGeneration != storage[attachment.id]?.uploadGeneration
    {
      shouldSuspendGenerationCommit = false
      generationCommitStarted = true
      await withCheckedContinuation { continuation in
        generationCommitContinuation = continuation
      }
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
