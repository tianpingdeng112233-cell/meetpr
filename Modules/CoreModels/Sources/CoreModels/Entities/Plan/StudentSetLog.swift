import Foundation

/// A set the student actually recorded. Historically always attached to a
/// prescribed plan set; since spec 045 (backend spec 010) a log can also be
/// adhoc (born outside any plan) or orphaned (its plan slot was deleted —
/// the row survives with `planExerciseID == nil`).
/// Wire shape (`GET /students/:id/sets`): weight_kg / rpe are Decimal-as-string.
public struct StudentSetLog: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  public let planExerciseID: UUID?
  /// Direct exercise identity (nil only on rows fetched from pre-spec-010
  /// backends; current backends always send it).
  public let exerciseID: UUID?
  /// Client-local training day (YYYY-MM-DD), the session anchor for adhoc
  /// rows. Nil only on rows fetched from pre-spec-010 backends.
  public let loggedDate: String?
  public let adhoc: Bool
  /// True when a past planned set was imported as assumed-complete history.
  /// Assumed rows remain visible in history but never count as the student's
  /// own completion statistics (spec 053).
  public let assumed: Bool
  public let setIndex: Int
  public let loggedAt: Date
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let failed: Bool

  public init(
    id: UUID,
    studentID: UUID,
    planExerciseID: UUID?,
    exerciseID: UUID? = nil,
    loggedDate: String? = nil,
    adhoc: Bool = false,
    assumed: Bool = false,
    setIndex: Int,
    loggedAt: Date,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    completed: Bool,
    failed: Bool = false
  ) {
    self.id = id
    self.studentID = studentID
    self.planExerciseID = planExerciseID
    self.exerciseID = exerciseID
    self.loggedDate = loggedDate
    self.adhoc = adhoc
    self.assumed = assumed
    self.setIndex = setIndex
    self.loggedAt = loggedAt
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
    self.failed = failed
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    planExerciseID = try container.decodeIfPresent(UUID.self, forKey: .planExerciseID)
    exerciseID = try container.decodeIfPresent(UUID.self, forKey: .exerciseID)
    loggedDate = try container.decodeIfPresent(String.self, forKey: .loggedDate)
    adhoc = try container.decodeIfPresent(Bool.self, forKey: .adhoc) ?? false
    assumed = try container.decodeIfPresent(Bool.self, forKey: .assumed) ?? false
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    loggedAt = try container.decode(Date.self, forKey: .loggedAt)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
    reps = try container.decode(Int.self, forKey: .reps)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    completed = try container.decode(Bool.self, forKey: .completed)
    failed = try container.decodeIfPresent(Bool.self, forKey: .failed) ?? false
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(studentID, forKey: .studentID)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encodeIfPresent(exerciseID, forKey: .exerciseID)
    try container.encodeIfPresent(loggedDate, forKey: .loggedDate)
    try container.encode(adhoc, forKey: .adhoc)
    try container.encode(assumed, forKey: .assumed)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encode(loggedAt, forKey: .loggedAt)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encode(completed, forKey: .completed)
    try container.encode(failed, forKey: .failed)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case studentID = "studentId"
    case planExerciseID = "planExerciseId"
    case exerciseID = "exerciseId"
    case loggedDate
    case adhoc
    case assumed
    case setIndex
    case loggedAt
    case weightKg
    case reps
    case rpe
    case completed
    case failed
  }
}
