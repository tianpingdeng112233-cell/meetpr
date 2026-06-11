import CoreModels
import Foundation
import RepositoryContracts

/// In-memory coach video wall for demo builds, previews, and tests. The
/// default (empty) instance doubles as the no-backend fallback: the grid
/// shows its empty state.
public actor InMemoryCoachStudentVideoRepository: CoachStudentVideoRepository {
  public enum InMemoryError: Error, Equatable, Sendable {
    case missingPlaybackURL(UUID)
  }

  private let videosByStudent: [UUID: [StudentVideo]]
  private let playbackURLs: [UUID: URL]

  public init(seed: [UUID: [StudentVideo]] = [:], playbackURLs: [UUID: URL] = [:]) {
    self.videosByStudent = seed
    self.playbackURLs = playbackURLs
  }

  public func fetchVideos(studentID: UUID) async throws -> [StudentVideo] {
    (videosByStudent[studentID] ?? []).sorted { $0.createdAt > $1.createdAt }
  }

  public func playbackURL(videoID: UUID) async throws -> URL {
    guard let url = playbackURLs[videoID] else {
      throw InMemoryError.missingPlaybackURL(videoID)
    }
    return url
  }
}
