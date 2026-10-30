import CoreModels
import Foundation

/// Read-only scope=all payload; planned-only consumers retain SetLogDTO.
public struct CoachSetLogDTO: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  public let planExerciseID: UUID?
  public let planDayID: UUID?
  public let adhoc: Bool
  public let exerciseID: UUID?
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let actualRIR: Int?
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
    planExerciseID: UUID?,
    planDayID: UUID? = nil,
    adhoc: Bool = false,
    exerciseID: UUID? = nil,
    setIndex: Int,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    actualRIR: Int? = nil,
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
    self.planDayID = planDayID
    self.adhoc = adhoc
    self.exerciseID = exerciseID
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.actualRIR = actualRIR
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
    planExerciseID = try container.decodeIfPresent(UUID.self, forKey: .planExerciseID)
    planDayID = try container.decodeIfPresent(UUID.self, forKey: .planDayID)
    adhoc = try container.decodeIfPresent(Bool.self, forKey: .adhoc) ?? false
    exerciseID = try container.decodeIfPresent(UUID.self, forKey: .exerciseID)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
    reps = try container.decode(Int.self, forKey: .reps)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    actualRIR = try container.decodeIfPresent(Int.self, forKey: .actualRIR)
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
    try container.encodeIfPresent(planExerciseID, forKey: .planExerciseID)
    try container.encodeIfPresent(planDayID, forKey: .planDayID)
    try container.encode(adhoc, forKey: .adhoc)
    try container.encodeIfPresent(exerciseID, forKey: .exerciseID)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encodeIfPresent(actualRIR, forKey: .actualRIR)
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
    case planDayID = "planDayId"
    case adhoc
    case exerciseID = "exerciseId"
    case setIndex
    case weightKg
    case reps
    case rpe
    case actualRIR = "actualRir"
    case coachRPE = "coachRpe"
    case completed
    case failed
    case assumed
    case loggedAt
    case loggedDate
  }
}

public struct CoachSetLogsResponseDTO: Decodable, Sendable {
  public let logs: [CoachSetLogDTO]
}
