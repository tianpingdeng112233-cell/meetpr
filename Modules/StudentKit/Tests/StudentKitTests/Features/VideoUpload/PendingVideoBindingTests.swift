import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func deletingDuringPendingVideoBindingDoesNotReviveUpload() async throws {
  let repository = PendingBindingGatedRepository()
  let service = MockVideoUploadService()
  let directory = FileManager.default.temporaryDirectory.appending(path: "pending-bind-\(UUID())")
  defer { try? FileManager.default.removeItem(at: directory) }
  let manager = VideoUploadManager(
    service: service, exporter: MockVideoExporter(), repository: repository,
    configuration: VideoUploadHarness.testConfiguration(), filesDirectory: directory)
  let source = try makeTemporaryVideoSource()
  defer { try? FileManager.default.removeItem(at: source) }
  let pending = try await manager.retainForSet(
    sourceURL: source, draftID: UUID(), studentID: UUID(), trainingDate: Date())
  await repository.pauseBinding()
  let binding = Task { try? await manager.bindPending(recordID: pending.id, setLogID: UUID()) }
  try await waitUntil { await repository.isPaused }
  let removal = Task { await manager.remove(attachmentID: pending.id) }
  try await waitUntil { await manager.removingRecordIDs.contains(pending.id) }
  await repository.releaseBinding()
  _ = await binding.value
  await removal.value
  #expect(try await repository.fetch(id: pending.id) == nil)
  #expect(await service.calls.allSatisfy { !$0.hasPrefix("initiate") })
}

private actor PendingBindingGatedRepository: VideoAttachmentRepository {
  private var records: [UUID: VideoAttachment] = [:]
  private var shouldPause = false
  private var continuation: CheckedContinuation<Void, Never>?
  var isPaused: Bool { continuation != nil }
  func pauseBinding() { shouldPause = true }
  func releaseBinding() {
    continuation?.resume()
    continuation = nil
  }
  func save(_ attachment: VideoAttachment) async throws {
    if shouldPause && attachment.status == .pending && attachment.pendingDraftID == nil {
      shouldPause = false
      await withCheckedContinuation { continuation = $0 }
    }
    records[attachment.id] = attachment
  }
  func persistUploadedPart(
    _ part: VideoUploadedPart, recordID: UUID, expectedUploadGeneration: Int
  ) async throws -> VideoAttachment? {
    guard var record = records[recordID], record.uploadGeneration == expectedUploadGeneration else {
      return nil
    }
    record.uploadedParts.append(part)
    records[recordID] = record
    return record
  }
  func fetch(id: UUID) async throws -> VideoAttachment? { records[id] }
  func fetch(setLogID: UUID) async throws -> [VideoAttachment] {
    records.values.filter { $0.setLogID == setLogID }
  }
  func fetchAll(studentID: UUID) async throws -> [VideoAttachment] {
    records.values.filter { $0.studentID == studentID }
  }
  func delete(id: UUID) async throws { records[id] = nil }
  func playbackURL(for attachment: VideoAttachment) async throws -> URL? { nil }
}
