import CoreModels
import Foundation

// Mutable review state (spec 043 §E): the coach picks weeks, binds exercises and
// fills the values the parser left blank. Built from a `ParsedPlan` + catalog,
// consumed by `ImportPlanAssembler` once the completeness gate (§H) is clear.

struct ImportReviewSet: Equatable, Sendable, Identifiable {
  let id: UUID
  var setNumber: Int
  var targetReps: Int?
  var targetRepsMax: Int?
  var weightKg: Decimal?
  var rpe: Decimal?
  var setType: SetType
  var coachNote: String?
}

struct ImportReviewExercise: Equatable, Sendable, Identifiable {
  let id: UUID
  var rawName: String
  /// Bound catalog exercise; `nil` until the coach resolves the match.
  var boundExerciseID: UUID?
  var isMainLift: Bool
  var note: String?
  var sets: [ImportReviewSet]
}

struct ImportReviewDay: Equatable, Sendable, Identifiable {
  let id: UUID
  /// 0-based column position (0…6); mapped to 1…7 at assembly.
  var dayOfWeek: Int
  var exercises: [ImportReviewExercise]
}

struct ImportReviewWeek: Equatable, Sendable, Identifiable {
  let id: UUID
  var blockIndex: Int
  var isSelected: Bool
  var days: [ImportReviewDay]
}

/// Completeness gate (spec 043 §H) — import has its OWN validation; it does not
/// reuse the draft/`PlanningViewModel` rules. coachNote is always optional.
enum ImportCompleteness {
  static func isComplete(_ set: ImportReviewSet) -> Bool {
    guard let reps = set.targetReps, reps >= 1 else { return false }
    if let weight = set.weightKg, weight > 0 { return true }
    if let rpe = set.rpe, rpe >= 1, rpe <= 10 { return true }
    return false
  }

  static func isComplete(_ exercise: ImportReviewExercise) -> Bool {
    guard exercise.boundExerciseID != nil, !exercise.sets.isEmpty else { return false }
    return exercise.sets.allSatisfy(isComplete)
  }

  /// Whether every exercise across the selected weeks is publish-ready.
  static func isPublishable(_ weeks: [ImportReviewWeek]) -> Bool {
    let selected = weeks.filter(\.isSelected)
    guard !selected.isEmpty else { return false }
    let exercises = selected.flatMap { $0.days.flatMap(\.exercises) }
    guard !exercises.isEmpty else { return false }
    return exercises.allSatisfy(isComplete)
  }
}

enum ImportReviewBuilder {
  /// Builds review weeks from a parsed plan, auto-binding exact catalog matches
  /// and seeding each set with the parser's structured values. All weeks start
  /// selected; the coach unticks the ones they don't want.
  static func build(
    from plan: ParsedPlan,
    catalog: [Exercise],
    makeID: () -> UUID = { UUID() }
  ) -> [ImportReviewWeek] {
    plan.weeks.map { week in
      ImportReviewWeek(
        id: makeID(),
        blockIndex: week.blockIndex,
        isSelected: true,
        days: week.days.filter { !$0.isRest && !$0.exercises.isEmpty }.map { day in
          ImportReviewDay(
            id: makeID(),
            dayOfWeek: day.dayOfWeek,
            exercises: day.exercises.map { exercise in
              buildExercise(exercise, catalog: catalog, makeID: makeID)
            }
          )
        }
      )
    }
  }

  private static func buildExercise(
    _ parsed: ParsedExercise,
    catalog: [Exercise],
    makeID: () -> UUID
  ) -> ImportReviewExercise {
    let match = ExerciseMatcher.exactMatch(rawName: parsed.rawName, catalog: catalog)
    return ImportReviewExercise(
      id: makeID(),
      rawName: parsed.rawName,
      boundExerciseID: match?.id,
      isMainLift: match?.mainLiftFamily != nil,
      note: parsed.exerciseNote,
      sets: parsed.sets.enumerated().map { index, set in
        ImportReviewSet(
          id: makeID(),
          setNumber: index + 1,
          targetReps: set.reps,
          targetRepsMax: set.repsMax,
          weightKg: set.weightKg,
          rpe: set.rpe,
          setType: set.setType,
          coachNote: set.coachNote
        )
      }
    )
  }
}
