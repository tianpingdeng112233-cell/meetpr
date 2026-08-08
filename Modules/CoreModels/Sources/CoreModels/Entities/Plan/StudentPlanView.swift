import Foundation

/// Student-facing, read-only projection of the current cycle plan.
/// Produced by the coach-side publish mapper; the student side never sees the
/// coach's editing-time draft types (PlanRule / WeeklyVariation).
public struct StudentPlanView: Codable, Hashable, Sendable {
  public let cycleID: UUID
  public let weekIndex: Int
  public let startDate: Date
  /// Coach-authored cycle end before plan-level shifts are applied.
  public let endDate: Date?
  /// `.regular` when absent — pre-033 cached projections carry no kind.
  /// Drives the student dashboard "教练正在为你排第一份正式计划" row
  /// (spec 033 §12): an adaptation-week plan is not the first regular plan.
  public let planKind: PlanKind
  public let publishedAt: Date?
  public let totalShiftDays: Int
  public let latestShiftCreatedAt: Date?
  public let days: [StudentPlanDay]

  public init(
    cycleID: UUID,
    weekIndex: Int,
    startDate: Date,
    endDate: Date? = nil,
    planKind: PlanKind = .regular,
    publishedAt: Date? = nil,
    totalShiftDays: Int = 0,
    latestShiftCreatedAt: Date? = nil,
    days: [StudentPlanDay]
  ) {
    self.cycleID = cycleID
    self.weekIndex = weekIndex
    self.startDate = startDate
    self.endDate = endDate
    self.planKind = planKind
    self.publishedAt = publishedAt
    self.totalShiftDays = totalShiftDays
    self.latestShiftCreatedAt = latestShiftCreatedAt
    self.days = days
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    cycleID = try container.decode(UUID.self, forKey: .cycleID)
    weekIndex = try container.decode(Int.self, forKey: .weekIndex)
    startDate = try container.decode(Date.self, forKey: .startDate)
    endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
    planKind = try container.decodeIfPresent(PlanKind.self, forKey: .planKind) ?? .regular
    publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
    totalShiftDays = try container.decodeIfPresent(Int.self, forKey: .totalShiftDays) ?? 0
    latestShiftCreatedAt = try container.decodeIfPresent(Date.self, forKey: .latestShiftCreatedAt)
    days = try container.decode([StudentPlanDay].self, forKey: .days)
  }

  private enum CodingKeys: String, CodingKey {
    case cycleID = "cycleId"
    case weekIndex
    case startDate
    case endDate
    case planKind
    case publishedAt
    case totalShiftDays
    case latestShiftCreatedAt
    case days
  }
}

public struct StudentPlanDay: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let weekNumber: Int
  public let dayOfWeek: Int
  public let sortOrder: Int
  /// The coach-authored recommended date.
  public let scheduledDate: Date
  /// Retained for wire compatibility and coach-side badges. Student sequence
  /// progression deliberately does not consume this override (spec 071).
  public let shiftedToDate: Date?
  public let completedAt: Date?
  public let completionSource: String?
  public let exercises: [StudentPlanExercise]

  /// Effective shifted date retained for coach-side compatibility. Student
  /// sequence surfaces must use `scheduledDate` as their recommendation.
  public var date: Date {
    shiftedToDate ?? scheduledDate
  }

  public init(
    id: UUID,
    weekNumber: Int = 1,
    dayOfWeek: Int = 1,
    sortOrder: Int = 0,
    date: Date,
    shiftedToDate: Date? = nil,
    completedAt: Date? = nil,
    completionSource: String? = nil,
    exercises: [StudentPlanExercise]
  ) {
    self.id = id
    self.weekNumber = weekNumber
    self.dayOfWeek = dayOfWeek
    self.sortOrder = sortOrder
    self.scheduledDate = date
    self.shiftedToDate = shiftedToDate
    self.completedAt = completedAt
    self.completionSource = completionSource
    self.exercises = exercises
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    weekNumber = try container.decodeIfPresent(Int.self, forKey: .weekNumber) ?? 1
    dayOfWeek = try container.decodeIfPresent(Int.self, forKey: .dayOfWeek) ?? 1
    sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    scheduledDate = try container.decode(Date.self, forKey: .date)
    shiftedToDate = try container.decodeIfPresent(Date.self, forKey: .shiftedToDate)
    completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    completionSource = try container.decodeIfPresent(String.self, forKey: .completionSource)
    exercises = try container.decode([StudentPlanExercise].self, forKey: .exercises)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(weekNumber, forKey: .weekNumber)
    try container.encode(dayOfWeek, forKey: .dayOfWeek)
    try container.encode(sortOrder, forKey: .sortOrder)
    try container.encode(scheduledDate, forKey: .date)
    try container.encodeIfPresent(shiftedToDate, forKey: .shiftedToDate)
    try container.encodeIfPresent(completedAt, forKey: .completedAt)
    try container.encodeIfPresent(completionSource, forKey: .completionSource)
    try container.encode(exercises, forKey: .exercises)
  }

  public func replacingCompletion(
    completedAt: Date?,
    source: String?
  ) -> StudentPlanDay {
    StudentPlanDay(
      id: id,
      weekNumber: weekNumber,
      dayOfWeek: dayOfWeek,
      sortOrder: sortOrder,
      date: scheduledDate,
      shiftedToDate: shiftedToDate,
      completedAt: completedAt,
      completionSource: source,
      exercises: exercises
    )
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case weekNumber
    case dayOfWeek
    case sortOrder
    case date
    case shiftedToDate
    case completedAt
    case completionSource
    case exercises
  }
}

/// Sequence-progression derivations shared by every student surface.
public struct StudentPlanSequence: Equatable, Sendable {
  public let orderedDays: [StudentPlanDay]

  public init(days: [StudentPlanDay]) {
    self.orderedDays = days.sorted(by: Self.precedes)
  }

  public var cursorDay: StudentPlanDay? {
    orderedDays.first { $0.completedAt == nil }
  }

  public func day(after dayID: UUID) -> StudentPlanDay? {
    guard let index = orderedDays.firstIndex(where: { $0.id == dayID }) else { return nil }
    return orderedDays.indices.contains(index + 1) ? orderedDays[index + 1] : nil
  }

  /// Canonical ordering from backend spec 035 §术语与排序正典. Do not add
  /// date-based or UI-local variants: the cursor must be clock-independent.
  public static func orderedDays(in plan: StudentPlanView) -> [StudentPlanDay] {
    plan.days.sorted(by: precedes)
  }

  /// The first incomplete day in canonical sequence order.
  public static func cursorDay(in plan: StudentPlanView) -> StudentPlanDay? {
    orderedDays(in: plan).first { $0.completedAt == nil }
  }

  public static func day(after dayID: UUID, in plan: StudentPlanView) -> StudentPlanDay? {
    let days = orderedDays(in: plan)
    guard let index = days.firstIndex(where: { $0.id == dayID }) else { return nil }
    return days.indices.contains(index + 1) ? days[index + 1] : nil
  }

  public static func precedes(_ lhs: StudentPlanDay, _ rhs: StudentPlanDay) -> Bool {
    if lhs.weekNumber != rhs.weekNumber { return lhs.weekNumber < rhs.weekNumber }
    if lhs.dayOfWeek != rhs.dayOfWeek { return lhs.dayOfWeek < rhs.dayOfWeek }
    if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}

public struct StudentPlanExercise: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let exercise: Exercise
  public let sequenceIndex: Int
  public let prescribedSets: [PrescribedSet]
  /// Exercise-level coach note (backend `plan_exercises.notes`) — the free-text
  /// 备注 the coach writes in the web plan editor. `nil` for pre-existing
  /// cached projections and unannotated exercises.
  public let notes: String?

  public init(
    id: UUID,
    exercise: Exercise,
    sequenceIndex: Int,
    prescribedSets: [PrescribedSet],
    notes: String? = nil
  ) {
    self.id = id
    self.exercise = exercise
    self.sequenceIndex = sequenceIndex
    self.prescribedSets = prescribedSets
    self.notes = notes
  }
}

/// A single prescribed set the student is asked to perform.
/// `setIndex` is zero-based throughout the execution domain.
/// `reps` is the single target or lower bound; `repsMax` is the optional upper
/// bound of a range. `rpe` is optional (the coach may leave it blank). Weights
/// use Decimal-as-string per the project codec to avoid float drift on 2.5kg
/// increments.
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
