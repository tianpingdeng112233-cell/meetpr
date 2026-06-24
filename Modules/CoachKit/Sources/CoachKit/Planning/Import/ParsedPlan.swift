import CoreModels
import Foundation

// Intermediate model produced by `PlanSheetParser` (spec 043 §C). This is NOT a
// draft: it is a faithful, structured read of the coach's xlsx grid that the
// import-review step turns into a published entity tree. Numbers are copied
// verbatim from the sheet — the parser never invents or computes a weight.

/// One prescribed set as read from the sheet. `weightKg` and `rpe` may both be
/// present at parse time (the sheet can carry a per-set RPE alongside a weight);
/// the assembler collapses to the single-target `PlanSet` shape, weight-first.
struct ParsedSet: Equatable, Sendable {
  var reps: Int?
  var repsMax: Int?
  var weightKg: Decimal?
  var rpe: Decimal?
  var setType: SetType
  /// Original shorthand the parser could not structure (e.g. 「70%top」「力竭」
  /// 「节奏3-1-0」). Surfaced to the coach in review and kept student-visible.
  var coachNote: String?

  init(
    reps: Int? = nil,
    repsMax: Int? = nil,
    weightKg: Decimal? = nil,
    rpe: Decimal? = nil,
    setType: SetType = .working,
    coachNote: String? = nil
  ) {
    self.reps = reps
    self.repsMax = repsMax
    self.weightKg = weightKg
    self.rpe = rpe
    self.setType = setType
    self.coachNote = coachNote
  }
}

/// One exercise (a name cell plus its sets). `isMainLift` is intentionally NOT
/// decided here — that follows from the catalog match (`mainLiftFamily`) in the
/// assembler (spec 043 §F), which the parser has no catalog to determine.
struct ParsedExercise: Equatable, Sendable {
  var rawName: String
  var sets: [ParsedSet]
  var exerciseNote: String?

  init(rawName: String, sets: [ParsedSet], exerciseNote: String? = nil) {
    self.rawName = rawName
    self.sets = sets
    self.exerciseNote = exerciseNote
  }
}

/// One training day within a week block. `dayOfWeek` is the 0-based column
/// position (0…6); rest days carry no exercises.
struct ParsedDay: Equatable, Sendable {
  var dayOfWeek: Int
  var isRest: Bool
  var exercises: [ParsedExercise]

  init(dayOfWeek: Int, isRest: Bool = false, exercises: [ParsedExercise] = []) {
    self.dayOfWeek = dayOfWeek
    self.isRest = isRest
    self.exercises = exercises
  }
}

/// One week block (between two date rows). `dateSerials` are the raw, possibly
/// corrupt serials from the header row — unreliable (the plan is re-dated from
/// the chosen start day at import), kept only for display/debugging.
struct ParsedWeek: Equatable, Sendable {
  var blockIndex: Int
  var dateSerials: [Double?]
  var days: [ParsedDay]

  /// Days that hold at least one exercise, in column order.
  var trainingDays: [ParsedDay] {
    days.filter { !$0.isRest && !$0.exercises.isEmpty }
  }
}

struct ParsedPlan: Equatable, Sendable {
  var weeks: [ParsedWeek]
}
