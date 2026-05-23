import Foundation

public struct CreateFeedbackRequestDTO: Encodable, Equatable, Sendable {
  public let studentID: UUID
  public let dayDate: String?
  public let planExerciseID: UUID?
  public let text: String

  public init(
    studentID: UUID,
    dayDate: Date? = nil,
    planExerciseID: UUID? = nil,
    text: String
  ) {
    self.studentID = studentID
    self.dayDate = dayDate.map(WireFormatting.dateOnlyString(from:))
    self.planExerciseID = planExerciseID
    self.text = text
  }

  public init(
    studentID: UUID,
    dayDate: String?,
    planExerciseID: UUID? = nil,
    text: String
  ) {
    self.studentID = studentID
    self.dayDate = dayDate
    self.planExerciseID = planExerciseID
    self.text = text
  }

  private enum CodingKeys: String, CodingKey {
    case studentID = "studentId"
    case dayDate
    case planExerciseID = "planExerciseId"
    case text
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
  public let text: String
  public let postedAt: Date
  public let readAt: Date?

  public init(
    id: UUID,
    coachID: UUID,
    studentID: UUID,
    dayDate: Date? = nil,
    planExerciseID: UUID? = nil,
    text: String,
    postedAt: Date,
    readAt: Date? = nil
  ) {
    self.id = id
    self.coachID = coachID
    self.studentID = studentID
    self.dayDate = dayDate
    self.planExerciseID = planExerciseID
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
    case text
    case postedAt
    case readAt
  }
}
