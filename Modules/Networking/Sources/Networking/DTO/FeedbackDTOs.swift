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
    case studentID = "student_id"
    case dayDate = "day_date"
    case planExerciseID = "plan_exercise_id"
    case text = "text"
  }
}

public struct FeedbackItemsResponseDTO: Codable, Equatable, Sendable {
  public let items: [FeedbackDTO]

  public init(items: [FeedbackDTO]) {
    self.items = items
  }

  // swiftlint:disable redundant_string_enum_value
  private enum CodingKeys: String, CodingKey {
    case items = "items"
  }
  // swiftlint:enable redundant_string_enum_value
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

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(coachID, forKey: .coachID)
    try container.encode(studentID, forKey: .studentID)

    if let dayDate {
      try container.encode(WireFormatting.dateOnlyString(from: dayDate), forKey: .dayDate)
    } else {
      try container.encodeNil(forKey: .dayDate)
    }

    try container.encodeIfPresent(planExerciseID, forKey: .planExerciseID)
    try container.encode(text, forKey: .text)
    try container.encode(postedAt, forKey: .postedAt)
    try container.encodeIfPresent(readAt, forKey: .readAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case coachID = "coach_id"
    case studentID = "student_id"
    case dayDate = "day_date"
    case planExerciseID = "plan_exercise_id"
    case text = "text"
    case postedAt = "posted_at"
    case readAt = "read_at"
  }
}
