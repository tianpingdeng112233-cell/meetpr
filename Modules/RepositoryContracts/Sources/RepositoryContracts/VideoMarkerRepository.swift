import CoreModels
import Foundation

public enum VideoMarkerRepositoryError: Error, Equatable, Sendable {
  case notFound
  /// The marker endpoint is not deployed (404) or the transport failed.
  /// Callers hide the marker surface entirely; playback must be unaffected.
  case unavailable
  /// The endpoint answered with any other error (403/409/5xx). Callers keep
  /// the marker surface visible and show a failure state instead of silently
  /// dropping the coach's or student's data.
  case failed
}

public protocol VideoMarkerRepository: Sendable {
  func markers(videoID: UUID) async throws -> [VideoMarker]
  func createMarker(
    videoID: UUID,
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String
  ) async throws -> VideoMarker
  func deleteMarker(videoID: UUID, markerID: UUID) async throws
}

public actor InMemoryVideoMarkerRepository: VideoMarkerRepository {
  private var storedMarkers: [VideoMarker]
  private let coachID: UUID
  private let now: @Sendable () -> Date
  private let makeID: @Sendable () -> UUID

  public init(
    seed: [VideoMarker] = [],
    coachID: UUID = UUID(),
    now: @escaping @Sendable () -> Date = { Date() },
    makeID: @escaping @Sendable () -> UUID = { UUID() }
  ) {
    storedMarkers = seed
    self.coachID = coachID
    self.now = now
    self.makeID = makeID
  }

  public func markers(videoID: UUID) async throws -> [VideoMarker] {
    storedMarkers
      .filter { $0.videoID == videoID }
      .sorted(by: Self.isOrderedBefore)
  }

  public func createMarker(
    videoID: UUID,
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String
  ) async throws -> VideoMarker {
    let marker = VideoMarker(
      id: makeID(),
      videoID: videoID,
      coachID: coachID,
      timeMilliseconds: max(0, timeMilliseconds),
      level: level,
      note: String(note.prefix(500)),
      createdAt: now()
    )
    storedMarkers.append(marker)
    return marker
  }

  public func deleteMarker(videoID: UUID, markerID: UUID) async throws {
    guard
      let index = storedMarkers.firstIndex(where: {
        $0.videoID == videoID && $0.id == markerID
      })
    else {
      throw VideoMarkerRepositoryError.notFound
    }
    storedMarkers.remove(at: index)
  }

  private static func isOrderedBefore(_ lhs: VideoMarker, _ rhs: VideoMarker) -> Bool {
    if lhs.timeMilliseconds != rhs.timeMilliseconds {
      return lhs.timeMilliseconds < rhs.timeMilliseconds
    }
    if lhs.createdAt != rhs.createdAt {
      return lhs.createdAt < rhs.createdAt
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}
