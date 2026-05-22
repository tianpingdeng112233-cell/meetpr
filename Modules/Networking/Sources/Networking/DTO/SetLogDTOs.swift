import CoreModels
import Foundation

public struct CreateSetLogRequestDTO: Encodable, Equatable, Sendable {
  public let planExerciseID: UUID
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool

  public init(
    planExerciseID: UUID,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool
  ) {
    self.planExerciseID = planExerciseID
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encode(completed, forKey: .completed)
  }

  private enum CodingKeys: String, CodingKey {
    case planExerciseID = "plan_exercise_id"
    case setIndex = "set_index"
    case weightKg = "weight_kg"
    case reps = "reps"
    case rpe = "rpe"
    case completed = "completed"
  }
}

public struct CreateSetLogResponseDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let loggedAt: Date

  public init(id: UUID, loggedAt: Date) {
    self.id = id
    self.loggedAt = loggedAt
  }

  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case loggedAt = "logged_at"
  }
}

public struct SetLogsResponseDTO: Codable, Equatable, Sendable {
  public let logs: [SetLogDTO]

  public init(logs: [SetLogDTO]) {
    self.logs = logs
  }

  // swiftlint:disable redundant_string_enum_value
  private enum CodingKeys: String, CodingKey {
    case logs = "logs"
  }
  // swiftlint:enable redundant_string_enum_value
}

public struct SetLogDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentID: UUID
  public let planExerciseID: UUID
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let loggedAt: Date

  public init(
    id: UUID,
    studentID: UUID,
    planExerciseID: UUID,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool,
    loggedAt: Date
  ) {
    self.id = id
    self.studentID = studentID
    self.planExerciseID = planExerciseID
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
    self.loggedAt = loggedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    planExerciseID = try container.decode(UUID.self, forKey: .planExerciseID)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
    reps = try container.decode(Int.self, forKey: .reps)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    completed = try container.decode(Bool.self, forKey: .completed)
    loggedAt = try container.decode(Date.self, forKey: .loggedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(studentID, forKey: .studentID)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encode(completed, forKey: .completed)
    try container.encode(loggedAt, forKey: .loggedAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case studentID = "student_id"
    case planExerciseID = "plan_exercise_id"
    case setIndex = "set_index"
    case weightKg = "weight_kg"
    case reps = "reps"
    case rpe = "rpe"
    case completed = "completed"
    case loggedAt = "logged_at"
  }
}
