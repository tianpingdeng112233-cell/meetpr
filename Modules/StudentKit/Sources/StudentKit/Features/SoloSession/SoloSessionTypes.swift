import CoreModels
import Foundation

/// One editable set row in a solo (adhoc) session. Unlike the coached
/// TodayWorkoutSetRowDraft there is no prescription — the student's own
/// numbers are the only truth; "重复上次" merely prefills them.
public struct SoloSetDraft: Equatable, Sendable, Identifiable {
  public let id: UUID
  public let exerciseID: UUID
  public let exerciseName: String
  public var weightKg: Decimal?
  public var reps: Int?
  public var rpe: Decimal?
  public var completed: Bool
  public var failed: Bool
  /// Server set_index once committed (spec 010 adhoc key component).
  public var committedSetIndex: Int?

  public init(
    id: UUID = UUID(),
    exerciseID: UUID,
    exerciseName: String,
    weightKg: Decimal? = nil,
    reps: Int? = nil,
    rpe: Decimal? = nil,
    completed: Bool = false,
    failed: Bool = false,
    committedSetIndex: Int? = nil
  ) {
    self.id = id
    self.exerciseID = exerciseID
    self.exerciseName = exerciseName
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.completed = completed
    self.failed = failed
    self.committedSetIndex = committedSetIndex
  }
}

/// Picker fodder: which exercises the student reaches for, derived from
/// their own history (no manual management, spec 045 轻结构).
public struct SoloExerciseSuggestions: Equatable, Sendable {
  /// Unique exercises from the most recent sessions, newest first.
  public let recent: [UUID]
  /// Exercises by 90-day set count, busiest first.
  public let frequent: [UUID]

  public init(recent: [UUID], frequent: [UUID]) {
    self.recent = recent
    self.frequent = frequent
  }

  public static let empty = SoloExerciseSuggestions(recent: [], frequent: [])
}
