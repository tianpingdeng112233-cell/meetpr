import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Suite("Set-video playback source")
struct VideoAttachmentPlaybackSourceTests {
  @Test("local file wins without requesting a cloud URL")
  func localFileWins() async throws {
    let harness = try PlaybackSourceHarness(localFileExists: true)

    let source = try await harness.manager.playbackSource(
      attachmentID: harness.attachment.id
    )

    #expect(source == .local(harness.localURL))
    #expect(await harness.repository.playbackRequestCount == 0)
  }

  @Test("missing local file requests a fresh cloud URL on every play")
  func missingLocalFileUsesFreshRemoteURL() async throws {
    let harness = try PlaybackSourceHarness(localFileExists: false)

    let first = try await harness.manager.playbackSource(
      attachmentID: harness.attachment.id
    )
    let second = try await harness.manager.playbackSource(
      attachmentID: harness.attachment.id
    )

    #expect(first == .remote(harness.remoteURL))
    #expect(second == .remote(harness.remoteURL))
    #expect(await harness.repository.playbackRequestCount == 2)
  }

  @MainActor
  @Test("local playback retry reopens the same file without refreshing cloud URL")
  func localRetryStaysLocal() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "local-retry-\(UUID().uuidString)", directoryHint: .isDirectory)
    let localURL = directory.appending(path: "retained.mp4")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data([0x01]).write(to: localURL)
    var remoteRefreshCount = 0

    let refreshedURL = try await VideoAttachmentPlaybackSource.local(localURL).retryURL(
      attachmentID: UUID(),
      refreshRemoteURL: { _ in
        remoteRefreshCount += 1
        return URL(fileURLWithPath: "/remote/should-not-load.mp4")
      }
    )

    #expect(refreshedURL == localURL)
    #expect(remoteRefreshCount == 0)
  }

  @MainActor
  @Test("remote playback retry requests a fresh cloud URL")
  func remoteRetryRefreshesCloudURL() async throws {
    let staleURL = URL(fileURLWithPath: "/remote/stale.mp4")
    let freshURL = URL(fileURLWithPath: "/remote/fresh.mp4")
    var remoteRefreshCount = 0

    let refreshedURL = try await VideoAttachmentPlaybackSource.remote(staleURL).retryURL(
      attachmentID: UUID(),
      refreshRemoteURL: { _ in
        remoteRefreshCount += 1
        return freshURL
      }
    )

    #expect(refreshedURL == freshURL)
    #expect(remoteRefreshCount == 1)
  }
}

private struct PlaybackSourceHarness {
  let attachment: VideoAttachment
  let repository: PlaybackSourceRepository
  let manager: VideoUploadManager
  let localURL: URL
  let remoteURL = URL(fileURLWithPath: "/remote/fresh.mp4")

  init(localFileExists: Bool) throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "playback-source-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let attachment = VideoAttachment(
      id: UUID(),
      setLogID: UUID(),
      studentID: UUID(),
      remoteAttachmentID: UUID(),
      status: .uploaded,
      contentType: "video/mp4",
      durationSeconds: 30,
      sizeBytes: 1,
      localFileName: "retained.mp4",
      recordedAt: Date(),
      uploadedAt: Date()
    )
    let localURL = directory.appending(path: "retained.mp4")
    if localFileExists {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try Data([0x01]).write(to: localURL)
    }
    let repository = PlaybackSourceRepository(
      attachment: attachment,
      playbackURL: remoteURL
    )
    self.attachment = attachment
    self.repository = repository
    self.localURL = localURL
    self.manager = VideoUploadManager(
      service: MockVideoUploadService(),
      exporter: MockVideoExporter(),
      repository: repository,
      filesDirectory: directory
    )
  }
}

private actor PlaybackSourceRepository: VideoAttachmentRepository {
  private var attachment: VideoAttachment
  private let url: URL
  private(set) var playbackRequestCount = 0

  init(attachment: VideoAttachment, playbackURL: URL) {
    self.attachment = attachment
    self.url = playbackURL
  }

  func save(_ attachment: VideoAttachment) async throws {
    self.attachment = attachment
  }

  func fetch(id: UUID) async throws -> VideoAttachment? {
    attachment.id == id ? attachment : nil
  }

  func fetch(setLogID: UUID) async throws -> [VideoAttachment] {
    attachment.setLogID == setLogID ? [attachment] : []
  }

  func fetchAll(studentID: UUID) async throws -> [VideoAttachment] {
    attachment.studentID == studentID ? [attachment] : []
  }

  func delete(id: UUID) async throws {}

  func playbackURL(for attachment: VideoAttachment) async throws -> URL? {
    playbackRequestCount += 1
    return url
  }
}
