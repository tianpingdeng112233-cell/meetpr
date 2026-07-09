import Foundation

/// A set the student actually recorded against a prescribed set.
/// Wire shape (`GET /students/:id/sets`): weight_kg / rpe are Decimal-as-string.
public struct StudentSetLog: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  public let planExerciseID: UUID
  public let setIndex: Int
  public let loggedAt: Date
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let failed: Bool
  /// Coach-confirmed import of a past prescription, rather than a set the
  /// student actually recorded. It displays as completed but never feeds PR/e1RM.
  public let assumed: Bool

  public init(
    id: UUID,
    studentID: UUID,
    planExerciseID: UUID,
    setIndex: Int,
    loggedAt: Date,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool,
    failed: Bool = false,
    assumed: Bool = false
  ) {
    self.id = id
    self.studentID = studentID
    self.planExerciseID = planExerciseID
    self.setIndex = setIndex
    self.loggedAt = loggedAt
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
    self.failed = failed
    self.assumed = assumed
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    planExerciseID = try container.decode(UUID.self, forKey: .planExerciseID)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    loggedAt = try container.decode(Date.self, forKey: .loggedAt)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
    reps = try container.decode(Int.self, forKey: .reps)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    completed = try container.decode(Bool.self, forKey: .completed)
    failed = try container.decodeIfPresent(Bool.self, forKey: .failed) ?? false
    assumed = try container.decodeIfPresent(Bool.self, forKey: .assumed) ?? false
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(studentID, forKey: .studentID)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encode(loggedAt, forKey: .loggedAt)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encode(completed, forKey: .completed)
    try container.encode(failed, forKey: .failed)
    try container.encode(assumed, forKey: .assumed)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case studentID = "studentId"
    case planExerciseID = "planExerciseId"
    case setIndex
    case loggedAt
    case weightKg
    case reps
    case rpe
    case completed
    case failed
    case assumed
  }
}
