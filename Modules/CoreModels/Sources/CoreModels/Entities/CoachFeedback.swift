import Foundation

/// A coach's free-text feedback to a student, optionally scoped to a day or a
/// specific plan exercise. Wire shape (`GET /students/:id/feedback`):
/// `day_date` is `YYYY-MM-DD` or null; `posted_at` / `read_at` are ISO timestamps.
public struct CoachFeedback: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let coachID: UUID
  public let studentID: UUID
  public let dayDate: Date?
  public let planExerciseID: UUID?
  public let videoID: UUID?
  public let video: CoachFeedbackVideo?
  public let text: String
  public let postedAt: Date
  public let readAt: Date?

  public init(
    id: UUID,
    coachID: UUID,
    studentID: UUID,
    dayDate: Date? = nil,
    planExerciseID: UUID? = nil,
    videoID: UUID? = nil,
    video: CoachFeedbackVideo? = nil,
    text: String,
    postedAt: Date,
    readAt: Date? = nil
  ) {
    self.id = id
    self.coachID = coachID
    self.studentID = studentID
    self.dayDate = dayDate
    self.planExerciseID = planExerciseID
    self.videoID = videoID
    self.video = video
    self.text = text
    self.postedAt = postedAt
    self.readAt = readAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case coachID = "coachId"
    case studentID = "studentId"
    case dayDate
    case planExerciseID = "planExerciseId"
    case videoID = "videoId"
    case video
    case text
    case postedAt
    case readAt
  }
}
