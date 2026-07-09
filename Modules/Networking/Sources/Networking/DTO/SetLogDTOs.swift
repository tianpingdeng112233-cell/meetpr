import CoreModels
import Foundation

public struct CreateSetLogRequestDTO: Encodable, Equatable, Sendable {
  public let planExerciseID: UUID
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let failed: Bool

  public init(
    planExerciseID: UUID,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool,
    failed: Bool = false
  ) {
    self.planExerciseID = planExerciseID
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
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
    try container.encode(failed, forKey: .failed)
  }

  private enum CodingKeys: String, CodingKey {
    case planExerciseID = "planExerciseId"
    case setIndex
    case weightKg
    case reps
    case rpe
    case completed
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
  /// Nil for rows born outside a plan (adhoc) and for plan rows orphaned by
  /// plan deletion (backend spec 010, served under `scope=all`).
  public let planExerciseID: UUID?
  public let exerciseID: UUID?
  /// Client-local training day (YYYY-MM-DD). Plain string on the wire — not
  /// a timestamp, so it must not go through the ISO8601 date strategy.
  public let loggedDate: String?
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let failed: Bool
  public let adhoc: Bool
  public let assumed: Bool
  public let loggedAt: Date

  public init(
    id: UUID,
    studentID: UUID,
    planExerciseID: UUID?,
    exerciseID: UUID? = nil,
    loggedDate: String? = nil,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool,
    failed: Bool = false,
    adhoc: Bool = false,
    assumed: Bool = false,
    loggedAt: Date
  ) {
    self.id = id
    self.studentID = studentID
    self.planExerciseID = planExerciseID
    self.exerciseID = exerciseID
    self.loggedDate = loggedDate
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
    self.failed = failed
    self.adhoc = adhoc
    self.assumed = assumed
    self.loggedAt = loggedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    planExerciseID = try container.decodeIfPresent(UUID.self, forKey: .planExerciseID)
    exerciseID = try container.decodeIfPresent(UUID.self, forKey: .exerciseID)
    loggedDate = try container.decodeIfPresent(String.self, forKey: .loggedDate)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
    reps = try container.decode(Int.self, forKey: .reps)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    completed = try container.decode(Bool.self, forKey: .completed)
    failed = try container.decodeIfPresent(Bool.self, forKey: .failed) ?? false
    adhoc = try container.decodeIfPresent(Bool.self, forKey: .adhoc) ?? false
    assumed = try container.decodeIfPresent(Bool.self, forKey: .assumed) ?? false
    loggedAt = try container.decode(Date.self, forKey: .loggedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(studentID, forKey: .studentID)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encodeIfPresent(exerciseID, forKey: .exerciseID)
    try container.encodeIfPresent(loggedDate, forKey: .loggedDate)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encode(completed, forKey: .completed)
    try container.encode(failed, forKey: .failed)
    try container.encode(adhoc, forKey: .adhoc)
    try container.encode(assumed, forKey: .assumed)
    try container.encode(loggedAt, forKey: .loggedAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case studentID = "studentId"
    case planExerciseID = "planExerciseId"
    case exerciseID = "exerciseId"
    case loggedDate
    case setIndex
    case weightKg
    case reps
    case rpe
    case completed
    case failed
    case adhoc
    case assumed
    case loggedAt
  }
}

/// Body for the adhoc shape of `POST /sets/log` (backend spec 010): a set
/// born outside any plan, keyed by exercise + client-local training day.
public struct CreateAdhocSetLogRequestDTO: Encodable, Equatable, Sendable {
  public let exerciseID: UUID
  public let loggedDate: String
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let failed: Bool

  public init(
    exerciseID: UUID,
    loggedDate: String,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool,
    failed: Bool = false
  ) {
    self.exerciseID = exerciseID
    self.loggedDate = loggedDate
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
    self.failed = failed
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(exerciseID, forKey: .exerciseID)
    try container.encode(loggedDate, forKey: .loggedDate)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encode(reps, forKey: .reps)
    try container.encode(completed, forKey: .completed)
    try container.encode(failed, forKey: .failed)
  }

  private enum CodingKeys: String, CodingKey {
    case exerciseID = "exerciseId"
    case loggedDate
    case setIndex
    case weightKg
    case reps
    case rpe
    case completed
    case failed
  }
}
