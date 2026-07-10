import Foundation

/// Student-facing, read-only projection of the current cycle plan.
/// Produced by the coach-side publish mapper; the student side never sees the
/// coach's editing-time draft types (PlanRule / WeeklyVariation).
public struct StudentPlanView: Codable, Hashable, Sendable {
  public let cycleID: UUID
  public let weekIndex: Int
  public let startDate: Date
  /// `.regular` when absent — pre-033 cached projections carry no kind.
  /// Drives the student dashboard "教练正在为你排第一份正式计划" row
  /// (spec 033 §12): an adaptation-week plan is not the first regular plan.
  public let planKind: PlanKind
  public let blockType: String?
  public let mesocyclePhase: String?
  public let trainingMax: Decimal?
  public let tmSetAt: Date?
  public let days: [StudentPlanDay]

  public init(
    cycleID: UUID,
    weekIndex: Int,
    startDate: Date,
    planKind: PlanKind = .regular,
    blockType: String? = nil,
    mesocyclePhase: String? = nil,
    trainingMax: Decimal? = nil,
    tmSetAt: Date? = nil,
    days: [StudentPlanDay]
  ) {
    self.cycleID = cycleID
    self.weekIndex = weekIndex
    self.startDate = startDate
    self.planKind = planKind
    self.blockType = blockType
    self.mesocyclePhase = mesocyclePhase
    self.trainingMax = trainingMax
    self.tmSetAt = tmSetAt
    self.days = days
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    cycleID = try container.decode(UUID.self, forKey: .cycleID)
    weekIndex = try container.decode(Int.self, forKey: .weekIndex)
    startDate = try container.decode(Date.self, forKey: .startDate)
    planKind = try container.decodeIfPresent(PlanKind.self, forKey: .planKind) ?? .regular
    blockType = try container.decodeIfPresent(String.self, forKey: .blockType)
    mesocyclePhase = try container.decodeIfPresent(String.self, forKey: .mesocyclePhase)
    trainingMax = try container.decodeDecimalIfPresent(forKey: .trainingMax)
    tmSetAt = try container.decodeIfPresent(Date.self, forKey: .tmSetAt)
    days = try container.decode([StudentPlanDay].self, forKey: .days)
  }

  private enum CodingKeys: String, CodingKey {
    case cycleID = "cycleId"
    case weekIndex
    case startDate
    case planKind
    case blockType
    case mesocyclePhase
    case trainingMax
    case tmSetAt
    case days
  }
}

public struct StudentPlanDay: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  /// The coach-authored slot date before a one-day shift.
  public let scheduledDate: Date
  /// Backend override for this slot. Consumers use `date`, never this value,
  /// for calendar placement and today checks.
  public let shiftedToDate: Date?
  public let exercises: [StudentPlanExercise]

  /// The single effective date used throughout the student and coach apps.
  public var date: Date {
    shiftedToDate ?? scheduledDate
  }

  public init(
    id: UUID,
    date: Date,
    shiftedToDate: Date? = nil,
    exercises: [StudentPlanExercise]
  ) {
    self.id = id
    self.scheduledDate = date
    self.shiftedToDate = shiftedToDate
    self.exercises = exercises
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    scheduledDate = try container.decode(Date.self, forKey: .date)
    shiftedToDate = try container.decodeIfPresent(Date.self, forKey: .shiftedToDate)
    exercises = try container.decode([StudentPlanExercise].self, forKey: .exercises)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(scheduledDate, forKey: .date)
    try container.encodeIfPresent(shiftedToDate, forKey: .shiftedToDate)
    try container.encode(exercises, forKey: .exercises)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case date
    case shiftedToDate
    case exercises
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
  public let restSeconds: Int?
  /// Student-visible coach cue for this set (spec 043 §G): the original
  /// shorthand the coach kept as context next to the structured target.
  /// `nil` for pre-043 data.
  public let coachNote: String?

  public init(
    id: UUID,
    setIndex: Int,
    weightKg: Decimal? = nil,
    reps: Int? = nil,
    repsMax: Int? = nil,
    rpe: Decimal? = nil,
    restSeconds: Int? = nil,
    coachNote: String? = nil
  ) {
    self.id = id
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.repsMax = repsMax
    self.rpe = rpe
    self.restSeconds = restSeconds
    self.coachNote = coachNote
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    weightKg = try container.decodeDecimalIfPresent(forKey: .weightKg)
    reps = try container.decodeIfPresent(Int.self, forKey: .reps)
    repsMax = try container.decodeIfPresent(Int.self, forKey: .repsMax)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
    coachNote = try container.decodeIfPresent(String.self, forKey: .coachNote)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encodeDecimalStringIfPresent(weightKg, forKey: .weightKg)
    try container.encodeIfPresent(reps, forKey: .reps)
    try container.encodeIfPresent(repsMax, forKey: .repsMax)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
    try container.encodeIfPresent(coachNote, forKey: .coachNote)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case setIndex
    case weightKg
    case reps
    case repsMax
    case rpe
    case restSeconds
    case coachNote
  }
}
