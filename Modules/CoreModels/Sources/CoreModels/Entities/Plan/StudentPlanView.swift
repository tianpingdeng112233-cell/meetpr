import Foundation

/// Student-facing, read-only projection of the current cycle plan.
/// Produced by the coach-side publish mapper; the student side never sees the
/// coach's editing-time draft types (PlanRule / WeeklyVariation).
public struct StudentPlanView: Codable, Hashable, Sendable {
  public let cycleID: UUID
  public let weekIndex: Int
  public let startDate: Date
  public let days: [StudentPlanDay]

  public init(cycleID: UUID, weekIndex: Int, startDate: Date, days: [StudentPlanDay]) {
    self.cycleID = cycleID
    self.weekIndex = weekIndex
    self.startDate = startDate
    self.days = days
  }

  private enum CodingKeys: String, CodingKey {
    case cycleID = "cycleId"
    case weekIndex
    case startDate
    case days
  }
}

public struct StudentPlanDay: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let date: Date
  public let exercises: [StudentPlanExercise]

  public init(id: UUID, date: Date, exercises: [StudentPlanExercise]) {
    self.id = id
    self.date = date
    self.exercises = exercises
  }
}

public struct StudentPlanExercise: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let exercise: Exercise
  public let sequenceIndex: Int
  public let prescribedSets: [PrescribedSet]

  public init(
    id: UUID,
    exercise: Exercise,
    sequenceIndex: Int,
    prescribedSets: [PrescribedSet]
  ) {
    self.id = id
    self.exercise = exercise
    self.sequenceIndex = sequenceIndex
    self.prescribedSets = prescribedSets
  }
}

/// A single prescribed set the student is asked to perform.
/// `reps` and `repsMax` are mutually exclusive (single value vs range); `rpe` is
/// optional (the coach may leave it blank). Weights use Decimal-as-string per the
/// project codec to avoid float drift on 2.5kg increments.
public struct PrescribedSet: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let setIndex: Int
  public let weightKg: Decimal?
  public let reps: Int?
  public let repsMax: Int?
  public let rpe: Decimal?

  public init(
    id: UUID,
    setIndex: Int,
    weightKg: Decimal? = nil,
    reps: Int? = nil,
    repsMax: Int? = nil,
    rpe: Decimal? = nil
  ) {
    self.id = id
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.repsMax = repsMax
    self.rpe = rpe
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    weightKg = try container.decodeDecimalIfPresent(forKey: .weightKg)
    reps = try container.decodeIfPresent(Int.self, forKey: .reps)
    repsMax = try container.decodeIfPresent(Int.self, forKey: .repsMax)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalStringIfPresent(weightKg, forKey: .weightKg)
    try container.encodeIfPresent(reps, forKey: .reps)
    try container.encodeIfPresent(repsMax, forKey: .repsMax)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case setIndex
    case weightKg
    case reps
    case repsMax
    case rpe
  }
}
