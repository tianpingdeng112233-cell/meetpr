import CoreModels
import Foundation

/// Aggregates the completed sets of a day's workout into the numbers and the
/// per-exercise breakdown shown on the post-session summary. Pure and total —
/// completed rows only; an empty or all-incomplete day yields zeros, a nil
/// average RPE, and no exercises.
public struct StudentSessionSummary: Equatable, Sendable {
  public let completedSets: Int
  public let totalReps: Int
  public let totalVolumeKg: Decimal
  public let averageRPE: Decimal?
  public let exercises: [ExercisePerformance]

  /// One exercise's representative ("top") completed set — the heaviest, with
  /// reps as the tiebreak — mirroring Juggernaut's per-exercise summary cards.
  public struct ExercisePerformance: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let topSetWeightKg: Decimal?
    public let topSetReps: Int
    public let topSetRPE: Decimal?
  }

  public init(drafts: [TodayWorkoutViewModel.SetRowDraft]) {
    let done = drafts.filter(\.completed)
    completedSets = done.count
    totalReps = done.reduce(0) { $0 + ($1.actualReps ?? 0) }
    totalVolumeKg = done.reduce(Decimal(0)) { total, draft in
      total + (draft.actualWeight ?? 0) * Decimal(draft.actualReps ?? 0)
    }
    let rpes = done.compactMap(\.actualRPE)
    averageRPE = rpes.isEmpty ? nil : rpes.reduce(Decimal(0), +) / Decimal(rpes.count)
    exercises = Self.topSets(of: done)
  }

  /// Groups completed sets by exercise (preserving first-appearance order) and
  /// keeps the heaviest set of each.
  private static func topSets(
    of done: [TodayWorkoutViewModel.SetRowDraft]
  ) -> [ExercisePerformance] {
    var order: [UUID] = []
    var byExercise: [UUID: [TodayWorkoutViewModel.SetRowDraft]] = [:]
    for draft in done {
      if byExercise[draft.planExerciseID] == nil {
        order.append(draft.planExerciseID)
      }
      byExercise[draft.planExerciseID, default: []].append(draft)
    }

    return order.compactMap { exerciseID in
      guard
        let sets = byExercise[exerciseID],
        let top = sets.max(by: { lhs, rhs in
          (lhs.actualWeight ?? 0, lhs.actualReps ?? 0) < (
            rhs.actualWeight ?? 0, rhs.actualReps ?? 0
          )
        })
      else { return nil }
      return ExercisePerformance(
        id: exerciseID,
        name: top.displayExerciseName,
        topSetWeightKg: top.actualWeight,
        topSetReps: top.actualReps ?? 0,
        topSetRPE: top.actualRPE
      )
    }
  }
}
