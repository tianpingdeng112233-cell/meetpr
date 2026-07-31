import CoreModels
import Foundation
import RepositoryContracts

public actor BackendVideoMarkerRepository: VideoMarkerRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func markers(videoID: UUID) async throws -> [VideoMarker] {
    do {
      let token = try await session.accessToken()
      return try await api.videoMarkers(videoID: videoID, accessToken: token).markers.map {
        $0.toDomain()
      }
    } catch {
      throw Self.repositoryError(from: error)
    }
  }

  public func createMarker(
    videoID: UUID,
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String
  ) async throws -> VideoMarker {
    do {
      let token = try await session.accessToken()
      return try await api.createVideoMarker(
        videoID: videoID,
        body: CreateVideoMarkerRequestDTO(
          timeMs: timeMilliseconds,
          level: level,
          note: note
        ),
        accessToken: token
      ).toDomain()
    } catch {
      throw Self.repositoryError(from: error)
    }
  }

  public func deleteMarker(videoID: UUID, markerID: UUID) async throws {
    do {
      let token = try await session.accessToken()
      try await api.deleteVideoMarker(
        videoID: videoID,
        markerID: markerID,
        accessToken: token
      )
    } catch {
      throw Self.repositoryError(from: error)
    }
  }

  /// A 404 means the endpoint is not deployed yet (the whole marker surface is
  /// optional while backend PR #150 rolls out); transport errors are equally
  /// invisible states. Everything else — 401 that survived the client's token
  /// refresh, 403, 409 ATTACHMENT_NOT_READY, 5xx — must stay loud so callers
  /// can show a failure instead of silently dropping data.
  static func repositoryError(from error: Error) -> VideoMarkerRepositoryError {
    if case APIError.httpStatus(let status, _) = error {
      return status == 404 ? .unavailable : .failed
    }
    if case APIClientError.httpStatus(let status, _) = error {
      return status == 404 ? .unavailable : .failed
    }
    if error is URLError {
      return .unavailable
    }
    return .failed
  }
}
