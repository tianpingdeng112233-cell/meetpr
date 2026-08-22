import Foundation

public struct CreateFeedbackRequestDTO: Encodable, Equatable, Sendable {
  public let studentID: UUID
  public let dayDate: String?
  public let planExerciseID: UUID?
  public let videoID: UUID?
  public let text: String

  public init(
    studentID: UUID,
    dayDate: Date? = nil,
    planExerciseID: UUID? = nil,
    videoID: UUID? = nil,
    text: String
  ) {
    self.studentID = studentID
    self.dayDate = dayDate.map(WireFormatting.dateOnlyString(from:))
    self.planExerciseID = planExerciseID
    self.videoID = videoID
    self.text = text
  }

  public init(
    studentID: UUID,
    dayDate: String?,
    planExerciseID: UUID? = nil,
    videoID: UUID? = nil,
    text: String
  ) {
    self.studentID = studentID
    self.dayDate = dayDate
    self.planExerciseID = planExerciseID
    self.videoID = videoID
    self.text = text
  }

  private enum CodingKeys: String, CodingKey {
    case studentID = "studentId"
    case dayDate
    case planExerciseID = "planExerciseId"
    case videoID = "videoId"
    case text
  }
}

/// Wire shape of spec 025's nested `video` object. Every field but `id` arrives
/// from a left join and can legitimately be null — see `CoachFeedbackVideo`.
public struct FeedbackVideoDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let exerciseName: String?
  public let exerciseNameEn: String?
  public let setIndex: Int?
  public let weightKg: String?
  public let reps: Int?
  public let rpe: String?
  public let loggedAt: Date?

  public init(
    id: UUID,
    exerciseName: String? = nil,
    exerciseNameEn: String? = nil,
    setIndex: Int? = nil,
    weightKg: String? = nil,
    reps: Int? = nil,
    rpe: String? = nil,
    loggedAt: Date? = nil
  ) {
    self.id = id
    self.exerciseName = exerciseName
    self.exerciseNameEn = exerciseNameEn
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.loggedAt = loggedAt
  }
}

public struct FeedbackItemsResponseDTO: Codable, Equatable, Sendable {
  public let items: [FeedbackDTO]

  public init(items: [FeedbackDTO]) {
    self.items = items
  }
}

public struct FeedbackDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let coachID: UUID
  public let studentID: UUID
  public let dayDate: Date?
  public let planExerciseID: UUID?
  public let videoID: UUID?
  public let video: FeedbackVideoDTO?
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
    video: FeedbackVideoDTO? = nil,
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
