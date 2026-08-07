import Foundation

extension VideoUploadManager {
  func playbackSource(attachmentID: UUID) async throws -> VideoAttachmentPlaybackSource? {
    guard let attachment = try await repository.fetch(id: attachmentID) else { return nil }
    let localURL = attachment.localFileName.map { filesDirectory.appending(path: $0) }
    let localFileExists = localURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    if let localSource = VideoAttachmentPlaybackSourceSelector.select(
      localURL: localURL,
      localFileExists: localFileExists,
      remoteURL: nil
    ) {
      return localSource
    }

    let remoteURL = try await repository.playbackURL(for: attachment)
    return VideoAttachmentPlaybackSourceSelector.select(
      localURL: localURL,
      localFileExists: false,
      remoteURL: remoteURL
    )
  }

  func freshRemotePlaybackURL(attachmentID: UUID) async throws -> URL {
    guard let attachment = try await repository.fetch(id: attachmentID),
      let url = try await repository.playbackURL(for: attachment)
    else {
      throw VideoAttachmentPlaybackError.unavailable
    }
    return url
  }
}
