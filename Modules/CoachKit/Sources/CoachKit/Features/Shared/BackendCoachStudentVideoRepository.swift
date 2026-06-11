import CoreModels
import Foundation
import Networking
import RepositoryContracts

public enum CoachStudentVideoRepositoryError: Error, Equatable, Sendable {
  /// The backend returned a playback URL string that does not parse.
  case malformedPlaybackURL(String)
}

/// Server-side video wall for one student (spec 029 second pass). No local
/// cache: the wall is small, metadata-only, and presigned playback URLs are
/// short-lived by design.
public actor BackendCoachStudentVideoRepository: CoachStudentVideoRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchVideos(studentID: UUID) async throws -> [StudentVideo] {
    let token = try await session.accessToken()
    let response = try await api.studentVideos(studentID: studentID, accessToken: token)
    return response.videos.map { $0.toDomain() }
  }

  public func playbackURL(videoID: UUID) async throws -> URL {
    let token = try await session.accessToken()
    let response = try await api.attachmentURL(attachmentID: videoID, accessToken: token)
    guard let url = URL(string: response.url) else {
      throw CoachStudentVideoRepositoryError.malformedPlaybackURL(response.url)
    }
    return url
  }
}
