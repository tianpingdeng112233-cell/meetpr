import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

@Test func uploadManagerRunsInitiatePartsCompleteInOrder() async throws {
  let harness = VideoUploadHarness(exporter: MockVideoExporter(duration: 30, exportedBytes: 2_560))
  let setLogID = UUID()
  let studentID = UUID()

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: setLogID,
    studentID: studentID
  )
  let uploaded = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])

  // 2560 bytes at 1024-byte parts → 3 parts, uploaded serially in order.
  let calls = await harness.service.calls
  #expect(
    calls == [
      "initiate:3:setlog-\(setLogID.uuidString)-\(record.id.uuidString).mp4",
      "part:1",
      "part:2",
      "part:3",
      "complete:1,2,3",
    ]
  )
  #expect(uploaded.sizeBytes == 2_560)
  #expect(uploaded.remoteAttachmentID == harness.service.remoteAttachmentID)
  #expect(uploaded.uploadedAt != nil)
  #expect(uploaded.setLogID == setLogID)
  #expect(uploaded.studentID == studentID)

  let exportedFile = harness.filesDirectory.appendingPathComponent("\(record.id.uuidString).mp4")
  #expect(FileManager.default.fileExists(atPath: exportedFile.path))
}

@Test func uploadManagerRetriesTransientPartFailures() async throws {
  let harness = VideoUploadHarness()
  // Part 2 fails twice; the third attempt (2 retries allowed) succeeds.
  await harness.service.setPartFailures([2: 2])

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])

  #expect(await harness.service.partAttempts[2] == 3)
  #expect(await harness.service.abortCount == 0)
}

@Test func uploadManagerMarksFailedAndAbortsAfterRetryExhaustion() async throws {
  let harness = VideoUploadHarness()
  // Part 1 fails more times than 1 initial attempt + 2 retries can absorb.
  await harness.service.setPartFailures([1: 5])

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  let failed = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])

  #expect(await harness.service.partAttempts[1] == 3)
  #expect(await harness.service.abortCount == 1)
  // The stale backend row is dead; a retry must re-initiate from scratch.
  #expect(failed.remoteAttachmentID == nil)
}

@Test func uploadManagerTreatsComplete409AsTerminalWithoutAbort() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setCompleteError(APIError.httpStatus(409, Data()))

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])

  // The backend row already left `uploading`; aborting it would just 409 too.
  #expect(await harness.service.abortCount == 0)
}

@Test func uploadManagerRejectsVideosOverTheDurationLimit() async throws {
  let harness = VideoUploadHarness(exporter: MockVideoExporter(duration: 121))
  let studentID = UUID()

  await #expect(throws: VideoUploadError.durationExceedsLimit(seconds: 121, maxSeconds: 120)) {
    try await harness.manager.enqueue(
      sourceURL: harness.sourceURL,
      setLogID: UUID(),
      studentID: studentID
    )
  }

  #expect(await harness.service.calls.isEmpty)
  #expect(try await harness.repository.fetchAll(studentID: studentID).isEmpty)
}

@Test func removeCancelsInFlightUploadAndAborts() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setHangOnParts(true)

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  // Wait until initiate finished (remote id persisted) and a part PUT hangs.
  try await waitUntil {
    try await harness.repository.fetch(id: record.id)?.remoteAttachmentID != nil
  }

  await harness.manager.remove(attachmentID: record.id)

  #expect(try await harness.repository.fetch(id: record.id) == nil)
  #expect(await harness.service.abortCount == 1)
  let exportedFile = harness.filesDirectory.appendingPathComponent("\(record.id.uuidString).mp4")
  #expect(!FileManager.default.fileExists(atPath: exportedFile.path))
}

@Test func retryAfterFailureReinitiatesFromScratch() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setPartFailures([1: 3])

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])

  await harness.manager.retry(attachmentID: record.id)
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])

  let initiateCalls = await harness.service.calls.filter { $0.hasPrefix("initiate:") }
  #expect(initiateCalls.count == 2)
}

@Test func recoverInterruptedUploadsMarksStaleRecordsFailed() async throws {
  let harness = VideoUploadHarness()
  let studentID = UUID()
  let stale = [
    makeRecord(studentID: studentID, status: .pending),
    makeRecord(studentID: studentID, status: .uploading),
  ]
  let done = makeRecord(studentID: studentID, status: .uploaded)
  for record in stale + [done] {
    try await harness.repository.save(record)
  }

  await harness.manager.recoverInterruptedUploads(studentID: studentID)

  for record in stale {
    #expect(try await harness.repository.fetch(id: record.id)?.status == .failed)
  }
  #expect(try await harness.repository.fetch(id: done.id)?.status == .uploaded)
}

@Test func enqueueReplacesEarlierVideoOnTheSameSet() async throws {
  let harness = VideoUploadHarness()
  let setLogID = UUID()
  let studentID = UUID()

  let first = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL, setLogID: setLogID, studentID: studentID)
  _ = try await waitForStatus(harness.repository, id: first.id, oneOf: [.uploaded])

  let second = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL, setLogID: setLogID, studentID: studentID)
  _ = try await waitForStatus(harness.repository, id: second.id, oneOf: [.uploaded])

  let forSet = try await harness.repository.fetch(setLogID: setLogID)
  #expect(forSet.map(\.id) == [second.id])
  #expect(try await harness.repository.fetch(id: first.id) == nil)
}

private func makeRecord(
  studentID: UUID,
  status: VideoAttachment.Status
) -> VideoAttachment {
  VideoAttachment(
    id: UUID(),
    setLogID: UUID(),
    studentID: studentID,
    remoteAttachmentID: status == .pending ? nil : UUID(),
    status: status,
    contentType: "video/mp4",
    durationSeconds: 30,
    sizeBytes: 1_000,
    localFileName: "file.mp4",
    recordedAt: Date(),
    uploadedAt: status == .uploaded ? Date() : nil
  )
}
