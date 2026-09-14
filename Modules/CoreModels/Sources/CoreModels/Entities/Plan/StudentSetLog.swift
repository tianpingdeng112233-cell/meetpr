import Foundation

/// A set the student actually recorded against a prescribed set.
/// `setIndex` is the wire's zero-based `set_logs.set_index`.
/// Wire shape (`GET /students/:id/sets`): weight_kg / rpe / coach_rpe are
/// Decimal-as-string.
public struct StudentSetLog: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  public let planExerciseID: UUID
  public let exerciseID: UUID?
  public let setIndex: Int
  public let loggedAt: Date
  public let loggedDate: String?
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let coachRPE: Decimal?
  public let completed: Bool
  public let failed: Bool
  public let assumed: Bool

  public init(
    id: UUID,
    studentID: UUID,
    planExerciseID: UUID,
    exerciseID: UUID? = nil,
    setIndex: Int,
    loggedAt: Date,
    loggedDate: String? = nil,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal? = nil,
    coachRPE: Decimal? = nil,
    completed: Bool,
    failed: Bool = false,
    assumed: Bool = false
  ) {
    self.id = id
    self.studentID = studentID
    self.planExerciseID = planExerciseID
    self.exerciseID = exerciseID
    self.setIndex = setIndex
    self.loggedAt = loggedAt
    self.loggedDate = loggedDate
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.coachRPE = coachRPE
    self.completed = completed
    self.failed = failed
    self.assumed = assumed
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    planExerciseID = try container.decode(UUID.self, forKey: .planExerciseID)
    exerciseID = try container.decodeIfPresent(UUID.self, forKey: .exerciseID)
    setIndex = try container.decode(Int.self, forKey: .setIndex)
    loggedAt = try container.decode(Date.self, forKey: .loggedAt)
    loggedDate = try container.decodeIfPresent(String.self, forKey: .loggedDate)
    weightKg = try container.decodeDecimal(forKey: .weightKg)
    reps = try container.decode(Int.self, forKey: .reps)
    rpe = try container.decodeDecimalIfPresent(forKey: .rpe)
    coachRPE = try container.decodeDecimalIfPresent(forKey: .coachRPE)
    completed = try container.decode(Bool.self, forKey: .completed)
    failed = try container.decodeIfPresent(Bool.self, forKey: .failed) ?? false
    assumed = try container.decodeIfPresent(Bool.self, forKey: .assumed) ?? false
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(studentID, forKey: .studentID)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encodeIfPresent(exerciseID, forKey: .exerciseID)
    try container.encode(setIndex, forKey: .setIndex)
    try container.encode(loggedAt, forKey: .loggedAt)
    try container.encodeIfPresent(loggedDate, forKey: .loggedDate)
    try container.encodeDecimalString(weightKg, forKey: .weightKg)
    try container.encode(reps, forKey: .reps)
    try container.encodeDecimalStringIfPresent(rpe, forKey: .rpe)
    try container.encodeDecimalStringIfPresent(coachRPE, forKey: .coachRPE)
    try container.encode(completed, forKey: .completed)
    try container.encode(failed, forKey: .failed)
    try container.encode(assumed, forKey: .assumed)
  }

  /// Gym-day cutoff shared with the backend `trainingDay` (04:00 local):
  /// a set logged before 04:00 belongs to the previous calendar day.
  public static let gymDayCutoffHour = 4

  /// The training day this log belongs to: the server-assigned `loggedDate`
  /// when present, else the gym-day of `loggedAt`.
  public func loggedDay(calendar: Calendar = .current) -> Date {
    if let loggedDate, let day = Self.parseLoggedDate(loggedDate, calendar: calendar) {
      return day
    }
    return Self.gymDay(of: loggedAt, calendar: calendar)
  }

  /// A backfilled log (spec 081 补记) carries a `loggedDate` that is not the
  /// gym-day of its server write timestamp. Anchor such logs at local noon of
  /// the training day so day-bucketed consumers place them on the day the
  /// student trained, not the day they opened the app. Live logs — whose
  /// `loggedDate` matches the gym-day of `loggedAt` — keep the exact timestamp.
  public static func resolvedLoggedAt(
    serverLoggedAt: Date,
    loggedDate: String?,
    calendar: Calendar = .current
  ) -> Date {
    guard let loggedDate, let day = parseLoggedDate(loggedDate, calendar: calendar),
      gymDay(of: serverLoggedAt, calendar: calendar) != day
    else { return serverLoggedAt }
    return localNoon(of: day, calendar: calendar) ?? serverLoggedAt
  }

  /// Local noon of the calendar day containing `day` (DST-safe: set the hour,
  /// never add 12 hours).
  public static func localNoon(of day: Date, calendar: Calendar) -> Date? {
    calendar.date(bySettingHour: 12, minute: 0, second: 0, of: calendar.startOfDay(for: day))
  }

  /// Same rule as `WorkoutDatePolicy`: before the cutoff hour the set belongs
  /// to the previous calendar day. Uses the local hour component, so DST
  /// transitions never shift the boundary.
  public static func gymDay(of date: Date, calendar: Calendar) -> Date {
    let today = calendar.startOfDay(for: date)
    guard calendar.component(.hour, from: date) < gymDayCutoffHour else { return today }
    return calendar.date(byAdding: .day, value: -1, to: today).map(calendar.startOfDay) ?? today
  }

  static func parseLoggedDate(_ value: String, calendar: Calendar) -> Date? {
    let parts = value.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case studentID = "studentId"
    case planExerciseID = "planExerciseId"
    case exerciseID = "exerciseId"
    case setIndex
    case loggedAt
    case loggedDate
    case weightKg
    case reps
    case rpe
    case coachRPE = "coachRpe"
    case completed
    case failed
    case assumed
  }

  /// Coach calibration is authoritative for strength calculations while the
  /// student's own entry remains available for display and audit.
  public var effectiveRPE: Decimal? {
    coachRPE ?? rpe
  }
}
