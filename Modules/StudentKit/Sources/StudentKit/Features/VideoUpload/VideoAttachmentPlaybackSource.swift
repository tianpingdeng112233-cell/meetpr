import Foundation

enum VideoAttachmentPlaybackSource: Equatable, Sendable {
  case local(URL)
  case remote(URL)

  var url: URL {
    switch self {
    case .local(let url), .remote(let url):
      url
    }
  }

  @MainActor
  func retryURL(
    attachmentID: UUID,
    refreshRemoteURL: @MainActor (UUID) async throws -> URL
  ) async throws -> URL {
    switch self {
    case .local(let url):
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw VideoAttachmentPlaybackError.unavailable
      }
      return url
    case .remote:
      return try await refreshRemoteURL(attachmentID)
    }
  }
}

enum VideoAttachmentPlaybackSourceSelector {
  static func select(
    localURL: URL?,
    localFileExists: Bool,
    remoteURL: URL?
  ) -> VideoAttachmentPlaybackSource? {
    if let localURL, localFileExists {
      return .local(localURL)
    }
    if let remoteURL {
      return .remote(remoteURL)
    }
    return nil
  }
}

enum VideoAttachmentPlaybackError: Error {
  case unavailable
}
