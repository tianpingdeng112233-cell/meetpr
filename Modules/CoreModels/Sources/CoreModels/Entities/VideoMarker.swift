import Foundation

public enum VideoMarkerLevel: String, Codable, CaseIterable, Hashable, Sendable {
  case info
  case warn
  case bad
}

/// A coach-authored timestamp annotation on one student training video.
public struct VideoMarker: Codable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let videoID: UUID
  public let coachID: UUID
  public let timeMilliseconds: Int
  public let level: VideoMarkerLevel
  public let note: String
  public let createdAt: Date

  public init(
    id: UUID,
    videoID: UUID,
    coachID: UUID,
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String,
    createdAt: Date
  ) {
    self.id = id
    self.videoID = videoID
    self.coachID = coachID
    self.timeMilliseconds = timeMilliseconds
    self.level = level
    self.note = note
    self.createdAt = createdAt
  }
}
