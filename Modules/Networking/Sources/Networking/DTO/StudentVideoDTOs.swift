import CoreModels
import Foundation

/// Wire shape for one `GET /students/:id/videos` item (backend spec 007).
/// Metadata only — playback URLs are exchanged per item via
/// `GET /uploads/:id/url`. Wire keys are snake_case; MeetPRCodec converts.
public struct StudentVideoDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let setLogId: UUID?
  public let planExerciseId: UUID?
  public let contentType: String
  public let sizeBytes: Int64
  public let filename: String?
  public let createdAt: Date
  public let loggedAt: Date?

  public init(
    id: UUID,
    setLogId: UUID?,
    planExerciseId: UUID?,
    contentType: String,
    sizeBytes: Int64,
    filename: String?,
    createdAt: Date,
    loggedAt: Date?
  ) {
    self.id = id
    self.setLogId = setLogId
    self.planExerciseId = planExerciseId
    self.contentType = contentType
    self.sizeBytes = sizeBytes
    self.filename = filename
    self.createdAt = createdAt
    self.loggedAt = loggedAt
  }

  public func toDomain() -> StudentVideo {
    StudentVideo(
      id: id,
      setLogID: setLogId,
      planExerciseID: planExerciseId,
      contentType: contentType,
      sizeBytes: sizeBytes,
      filename: filename,
      createdAt: createdAt,
      loggedAt: loggedAt
    )
  }
}

public struct StudentVideosResponseDTO: Codable, Equatable, Sendable {
  public let videos: [StudentVideoDTO]

  public init(videos: [StudentVideoDTO]) {
    self.videos = videos
  }
}
