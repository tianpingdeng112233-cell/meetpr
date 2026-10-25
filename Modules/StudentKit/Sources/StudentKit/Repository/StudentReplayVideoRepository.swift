import CoreModels
import Foundation
import Networking

/// Read-only access to server history, independent of the on-device upload queue.
public protocol StudentReplayVideoRepository: Sendable {
  func fetchVideos(studentID: UUID) async throws -> [StudentVideo]
  func playbackURL(videoID: UUID) async throws -> URL
}

public actor BackendStudentReplayVideoRepository: StudentReplayVideoRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchVideos(studentID: UUID) async throws -> [StudentVideo] {
    let token = try await session.accessToken()
    return try await api.studentVideos(studentID: studentID, accessToken: token).videos.map {
      $0.toDomain()
    }
  }

  public func playbackURL(videoID: UUID) async throws -> URL {
    let token = try await session.accessToken()
    let response = try await api.attachmentURL(attachmentID: videoID, accessToken: token)
    guard let url = URL(string: response.url) else {
      throw VideoAttachmentPlaybackError.unavailable
    }
    return url
  }
}
