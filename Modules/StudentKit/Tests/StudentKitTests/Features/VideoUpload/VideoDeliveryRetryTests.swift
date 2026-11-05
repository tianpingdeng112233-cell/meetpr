import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func manualRetryBypassesBackoffWithoutHidingFailure() async throws {
  let harness = VideoUploadHarness()
  let date = Date()
  let record = VideoAttachment(
    id: UUID(), setLogID: UUID(), studentID: UUID(), status: .pending,
    contentType: "video/mp4", durationSeconds: 30, sizeBytes: 100,
    localFileName: "retry.mp4", recordedAt: date, firstUploadFailureAt: date)
  try Data(repeating: 1, count: 100).write(to: harness.filesDirectory.appending(path: "retry.mp4"))
  try await harness.repository.save(record)
  await harness.service.setPartDelay(.milliseconds(100))
  await harness.manager.retry(attachmentID: record.id)
  let retrying = try #require(await harness.manager.attachments(studentID: record.studentID).first)
  #expect(VideoDeliveryPresentation.hasFailure(retrying))
  let delivered = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(delivered.setLogID == record.setLogID)
  #expect(!VideoDeliveryPresentation.hasFailure(delivered))
}

@Test func missingFileCanBeReplacedAndDeliveredToOriginalSet() async throws {
  let harness = VideoUploadHarness()
  let record = VideoAttachment(
    id: UUID(), setLogID: UUID(), studentID: UUID(), status: .pending,
    contentType: "video/mp4", durationSeconds: 5, sizeBytes: 100,
    localFileName: "deleted.mp4", recordedAt: Date(), firstUploadFailureAt: Date())
  let file = harness.filesDirectory.appending(path: "deleted.mp4")
  try Data([1]).write(to: file)
  try await harness.repository.save(record)
  try FileManager.default.removeItem(at: file)
  await harness.manager.retry(attachmentID: record.id)
  #expect(await harness.manager.attachments(studentID: record.studentID).first?.status == .failed)
  try await harness.manager.replaceMissingSource(
    attachmentID: record.id, sourceURL: harness.sourceURL)
  let delivered = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(delivered.setLogID == record.setLogID)
  #expect(delivered.trainingDate == record.trainingDate)
  #expect(delivered.durationSeconds == 30)
}

@Test func pendingMissingVideoRetainsDraftIdentityAndBindsAfterReplacement() async throws {
  let harness = VideoUploadHarness()
  let draftID = UUID()
  let date = Date(timeIntervalSince1970: 1_794_000_000)
  let pending = try await harness.manager.retainForSet(
    sourceURL: harness.sourceURL, draftID: draftID, studentID: UUID(), trainingDate: date)
  let retained = try #require(await harness.manager.retainedSourceURL(recordID: pending.id))
  try FileManager.default.removeItem(at: retained)
  await harness.manager.retry(attachmentID: pending.id)
  try await harness.manager.replaceMissingSource(
    attachmentID: pending.id, sourceURL: harness.sourceURL)
  let restored = try #require(try await harness.repository.fetch(id: pending.id))
  #expect(restored.pendingDraftID == draftID)
  #expect(restored.trainingDate == date)
  let canonicalID = UUID()
  _ = try await harness.manager.bindPending(recordID: pending.id, setLogID: canonicalID)
  let delivered = try await waitForStatus(harness.repository, id: pending.id, oneOf: [.uploaded])
  #expect(delivered.setLogID == canonicalID)
  #expect(delivered.pendingDraftID == nil)
}
