import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

@Test func backendRepositoryPersistsAcrossInstances() async throws {
  let directory = tempDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let first = makeBackendRepository(directory: directory)
  let attachment = makeAttachment(status: .failed)

  try await first.save(attachment)

  // A fresh instance over the same directory sees the saved record — this is
  // the app-relaunch path that recovery and retry depend on.
  let second = makeBackendRepository(directory: directory)
  #expect(try await second.fetch(id: attachment.id) == attachment)
  #expect(try await second.fetch(setLogID: attachment.setLogID) == [attachment])
  #expect(try await second.fetchAll(studentID: attachment.studentID) == [attachment])
}

@Test func backendRepositoryPersistsMultipartCheckpointAcrossInstances() async throws {
  let directory = tempDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let first = makeBackendRepository(directory: directory)
  var attachment = makeAttachment(status: .uploading)
  attachment.uploadPartCount = 3
  attachment.uploadPartTargets = [
    VideoUploadPartTarget(partNumber: 1, url: try #require(URL(string: "https://oss.test/1"))),
    VideoUploadPartTarget(partNumber: 2, url: try #require(URL(string: "https://oss.test/2"))),
    VideoUploadPartTarget(partNumber: 3, url: try #require(URL(string: "https://oss.test/3"))),
  ]
  attachment.uploadedParts = [VideoUploadedPart(partNumber: 1, etag: "etag-1")]
  attachment.uploadRetryCount = 2
  attachment.firstUploadFailureAt = Date(timeIntervalSince1970: 1_780_000_000)

  try await first.save(attachment)
  let restored = try await makeBackendRepository(directory: directory).fetch(id: attachment.id)

  #expect(restored == attachment)
}

@Test func backendRepositorySaveUpsertsByID() async throws {
  let directory = tempDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let repository = makeBackendRepository(directory: directory)
  var attachment = makeAttachment(status: .uploading)

  try await repository.save(attachment)
  attachment.status = .uploaded
  try await repository.save(attachment)

  let all = try await repository.fetchAll(studentID: attachment.studentID)
  #expect(all.count == 1)
  #expect(all.first?.status == .uploaded)
}

@Test func backendRepositoryDeleteRemovesRecord() async throws {
  let directory = tempDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let repository = makeBackendRepository(directory: directory)
  let attachment = makeAttachment(status: .uploaded)

  try await repository.save(attachment)
  try await repository.delete(id: attachment.id)

  #expect(try await repository.fetch(id: attachment.id) == nil)
}

@Test func backendRepositoryPlaybackURLRequiresUploadedStatus() async throws {
  let directory = tempDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let repository = makeBackendRepository(directory: directory)

  let pending = makeAttachment(status: .pending)
  #expect(try await repository.playbackURL(for: pending) == nil)
}

@Test func backendRepositoryPlaybackURLFetchesPresignedGET() async throws {
  let directory = tempDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let remoteID = UUID()
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    let path = request.url?.path() ?? ""
    #expect(path == "/uploads/\(remoteID.uuidString)/url")
    #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer token")
    return APIResponse(
      data: Data(#"{"url": "https://bucket.oss.test/key?sig=1", "expires_in": 900}"#.utf8),
      statusCode: 200
    )
  }
  let repository = BackendVideoAttachmentRepository(
    api: api, session: StubSessionReader(), directory: directory)

  var attachment = makeAttachment(status: .uploaded)
  attachment.remoteAttachmentID = remoteID

  let url = try await repository.playbackURL(for: attachment)
  #expect(url?.absoluteString == "https://bucket.oss.test/key?sig=1")
}

@Test func inMemoryRepositoryFiltersBySetLogAndStudent() async throws {
  let repository = InMemoryVideoAttachmentRepository()
  let mine = makeAttachment(status: .uploaded)
  let other = makeAttachment(status: .uploaded)

  try await repository.save(mine)
  try await repository.save(other)

  #expect(try await repository.fetch(setLogID: mine.setLogID) == [mine])
  #expect(try await repository.fetchAll(studentID: other.studentID) == [other])
  #expect(try await repository.playbackURL(for: mine) == nil)

  try await repository.delete(id: mine.id)
  #expect(try await repository.fetch(id: mine.id) == nil)
}

// MARK: - Helpers

private func tempDirectory() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent("video-repo-tests-\(UUID().uuidString)", isDirectory: true)
}

private func makeBackendRepository(directory: URL) -> BackendVideoAttachmentRepository {
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: Data(), statusCode: 500)
  }
  return BackendVideoAttachmentRepository(
    api: api, session: StubSessionReader(), directory: directory)
}

private func makeAttachment(status: VideoAttachment.Status) -> VideoAttachment {
  VideoAttachment(
    id: UUID(),
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: status == .pending ? nil : UUID(),
    status: status,
    contentType: "video/mp4",
    durationSeconds: 45,
    sizeBytes: 2_048,
    localFileName: "clip.mp4",
    recordedAt: Date(timeIntervalSince1970: 1_750_000_000),
    uploadedAt: status == .uploaded ? Date(timeIntervalSince1970: 1_750_000_100) : nil
  )
}

private struct StubSessionReader: SessionStateReader {
  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}
