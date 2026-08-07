import Foundation
import Networking
import Testing

@testable import StudentKit

@Test func uploadManagerReconcilesReadyComplete409AsUploaded() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setCompleteError(VideoUploadCompleteConflict(status: .ready))

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])

  #expect(await harness.service.abortCount == 0)
}

@Test(arguments: [VideoUploadRemoteStatus.aborted, .failed])
func uploadManagerTreatsTerminalComplete409AsFailed(
  status: VideoUploadRemoteStatus
) async throws {
  let harness = VideoUploadHarness()
  await harness.service.setCompleteError(VideoUploadCompleteConflict(status: status))

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])

  #expect(await harness.service.calls.filter { $0.hasPrefix("complete:") }.count == 1)
  #expect(await harness.service.abortCount == 0)
}

@Test(arguments: [VideoUploadRemoteStatus?.some(.completing), .none])
func uploadManagerRetriesTransientComplete409(
  status: VideoUploadRemoteStatus?
) async throws {
  let harness = VideoUploadHarness()
  await harness.service.setCompleteErrors([VideoUploadCompleteConflict(status: status)])

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])

  #expect(await harness.service.calls.filter { $0.hasPrefix("complete:") }.count == 2)
  #expect(await harness.service.partAttempts.values.allSatisfy { $0 == 1 })
  #expect(await harness.service.abortCount == 0)
}

@Test func complete409PayloadDecodesBackendStatus() {
  let ready = APIError.httpStatus(
    409,
    Data(#"{"error":"UPLOAD_INVALID_STATE","status":"ready"}"#.utf8)
  )
  let completing = APIError.httpStatus(
    409,
    Data(#"{"error":"UPLOAD_INVALID_STATE","status":"completing"}"#.utf8)
  )
  let malformed = APIError.httpStatus(409, Data("not-json".utf8))

  #expect(VideoUploadCompleteConflict(apiError: ready).status == .ready)
  #expect(VideoUploadCompleteConflict(apiError: completing).status == .completing)
  #expect(VideoUploadCompleteConflict(apiError: malformed).status == nil)
}
