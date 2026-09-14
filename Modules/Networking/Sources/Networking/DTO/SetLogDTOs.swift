import CoreModels
import Foundation

public struct CreateSetLogRequestDTO: Encodable, Equatable, Sendable {
  public let planExerciseID: UUID
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let loggedDate: String?
  public let failed: Bool

  public init(
    planExerciseID: UUID,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool,
    loggedDate: String? = nil,
    failed: Bool = false
  ) {
    self.planExerciseID = planExerciseID
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
    self.loggedDate = loggedDate
    self.failed = failed
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encode(completed, forKey: .completed)
    try container.encodeIfPresent(loggedDate, forKey: .loggedDate)
    try container.encode(failed, forKey: .failed)
  }

  private enum CodingKeys: String, CodingKey {
    case planExerciseID = "planExerciseId"
    case setIndex
    case weightKg
    case reps
    case rpe
    case completed
    case loggedDate
    case failed
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
    case id
    case loggedAt
  }
}

public struct SetLogsResponseDTO: Codable, Equatable, Sendable {
  public let logs: [SetLogDTO]

  public init(logs: [SetLogDTO]) {
    self.logs = logs
  }
}

public struct SetLogDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentID: UUID
  public let planExerciseID: UUID
  public let exerciseID: UUID?
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let coachRPE: Decimal?
  public let completed: Bool
  public let failed: Bool
  public let assumed: Bool
  public let loggedAt: Date
  /// Server-assigned training day (`YYYY-MM-DD`, the student's gym-day).
  public let loggedDate: String?

  public init(
    id: UUID,
    studentID: UUID,
    planExerciseID: UUID,
    exerciseID: UUID? = nil,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    coachRPE: Decimal? = nil,
    completed: Bool,
    failed: Bool = false,
    assumed: Bool = false,
    loggedAt: Date,
    loggedDate: String? = nil
  ) {
    self.id = id
    self.studentID = studentID
    self.planExerciseID = planExerciseID
    self.exerciseID = exerciseID
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.coachRPE = coachRPE
    self.completed = completed
    self.failed = failed
    self.assumed = assumed
    self.loggedAt = loggedAt
    self.loggedDate = loggedDate
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    planExerciseID = try container.decode(UUID.self, forKey: .planExerciseID)
    exerciseID = try container.decodeIfPresent(UUID.self, forKey: .exerciseID)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
    reps = try container.decode(Int.self, forKey: .reps)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    coachRPE = try container.decodeDecimalIfPresent(forKey: .coachRPE)
    completed = try container.decode(Bool.self, forKey: .completed)
    failed = try container.decodeIfPresent(Bool.self, forKey: .failed) ?? false
    assumed = try container.decodeIfPresent(Bool.self, forKey: .assumed) ?? false
    loggedAt = try container.decode(Date.self, forKey: .loggedAt)
    loggedDate = try container.decodeIfPresent(String.self, forKey: .loggedDate)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(studentID, forKey: .studentID)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encodeIfPresent(exerciseID, forKey: .exerciseID)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encodeDecimalStringIfPresent(coachRPE, forKey: .coachRPE)
    try container.encode(completed, forKey: .completed)
    try container.encode(failed, forKey: .failed)
    try container.encode(assumed, forKey: .assumed)
    try container.encode(loggedAt, forKey: .loggedAt)
    try container.encodeIfPresent(loggedDate, forKey: .loggedDate)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case studentID = "studentId"
    case planExerciseID = "planExerciseId"
    case exerciseID = "exerciseId"
    case setIndex
    case weightKg
    case reps
    case rpe
    case coachRPE = "coachRpe"
    case completed
    case failed
    case assumed
    case loggedAt
    case loggedDate
  }
}
