import CoreModels
import Foundation
import RepositoryContracts

/// In-memory 训练视频 inbox for demo builds, previews, and tests. The default
/// (empty) instance doubles as the no-backend fallback. `sendFeedback` is
/// authoritative here — it drops the exact video id from the queue, so the
/// demo never relies on the live impl's coarse `planExerciseID` matching.
public actor InMemoryCoachVideoQueueRepository: CoachVideoQueueRepository {
  public enum InMemoryError: Error, Equatable, Sendable {
    case missingPlaybackURL(UUID)
  }

  private var pending: [PendingVideoItem]
  private let playbackURLs: [UUID: URL]
  private let coachID: UUID

  public init(
    seed: [PendingVideoItem] = [],
    playbackURLs: [UUID: URL] = [:],
    coachID: UUID = UUID()
  ) {
    self.pending = seed
    self.playbackURLs = playbackURLs
    self.coachID = coachID
  }

  public func fetchPendingVideos() async throws -> [PendingVideoItem] {
    pending.sorted { $0.uploadedAt > $1.uploadedAt }
  }

  public func playbackURL(videoID: UUID) async throws -> URL {
    guard let url = playbackURLs[videoID] else {
      throw InMemoryError.missingPlaybackURL(videoID)
    }
    return url
  }

  public func sendFeedback(for item: PendingVideoItem, text: String) async throws -> CoachFeedback {
    pending.removeAll { $0.id == item.id }
    return CoachFeedback(
      id: UUID(),
      coachID: coachID,
      studentID: item.studentID,
      dayDate: item.dayDate,
      planExerciseID: item.planExerciseID,
      videoID: item.id,
      text: text,
      postedAt: Date(),
      readAt: nil
    )
  }
}
