import CoreModels
import Foundation

public struct VideoMarkerDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let videoID: UUID
  public let coachID: UUID
  public let timeMs: Int
  public let level: VideoMarkerLevel
  public let note: String
  public let createdAt: Date
  public let attachmentID: UUID?
  public let annotationURL: URL?
  public let annotationExpiresIn: Int?

  public init(
    id: UUID,
    videoID: UUID,
    coachID: UUID,
    timeMs: Int,
    level: VideoMarkerLevel,
    note: String,
    createdAt: Date,
    attachmentID: UUID? = nil,
    annotationURL: URL? = nil,
    annotationExpiresIn: Int? = nil
  ) {
    self.id = id
    self.videoID = videoID
    self.coachID = coachID
    self.timeMs = timeMs
    self.level = level
    self.note = note
    self.createdAt = createdAt
    self.attachmentID = attachmentID
    self.annotationURL = annotationURL
    self.annotationExpiresIn = annotationExpiresIn
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case videoID = "videoId"
    case coachID = "coachId"
    case timeMs
    case level
    case note
    case createdAt
    case attachmentID = "attachmentId"
    case annotationURL = "annotationUrl"
    case annotationExpiresIn
  }
}

public struct VideoMarkersResponseDTO: Codable, Equatable, Sendable {
  public let markers: [VideoMarkerDTO]

  public init(markers: [VideoMarkerDTO]) {
    self.markers = markers
  }
}

public struct CreateVideoMarkerRequestDTO: Codable, Equatable, Sendable {
  public let timeMs: Int
  public let level: VideoMarkerLevel
  public let note: String

  public init(timeMs: Int, level: VideoMarkerLevel, note: String) {
    self.timeMs = timeMs
    self.level = level
    self.note = note
  }
}
