import CoreModels
import Foundation

/// Read-only results for the settled-day overview; prescription counts exclude added work.
struct CompletedDayPresentation: Equatable, Sendable {
  struct Exercise: Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let number: Int
    let isAdded: Bool
    let prescribedCount: Int
    let loggedCount: Int
    let rows: [Row]

    var isComplete: Bool { isAdded || (prescribedCount > 0 && loggedCount == prescribedCount) }

    var summary: String {
      if isAdded {
        return String(localized: "student.completedDay.addedSets \(loggedCount)", bundle: .module)
      }
      return String(
        localized: "student.completedDay.loggedSets \(loggedCount) \(prescribedCount)",
        bundle: .module)
    }
  }

  struct Row: Equatable, Sendable, Identifiable {
    let id: UUID
    let number: Int
    let isExtra: Bool
    let failed: Bool
    let result: String

    init(draft: TodayWorkoutSetRowDraft, unit: UnitPreference) {
      id = draft.id
      number = draft.prescribed.setIndex + 1
      isExtra = draft.isExtra
      failed = draft.failed
      guard draft.completed || draft.failed else {
        result = "—"
        return
      }
      let weight = draft.actualWeight.map { UnitDisplay.weightText(kg: $0, unit: unit) } ?? "—"
      let reps = draft.actualReps.map(String.init) ?? "—"
      let rpe = draft.actualRPE.map { " · RPE \(StudentFormatting.decimal($0))" } ?? ""
      result = "\(weight) \(UnitDisplay.weightUnitSuffix(unit)) × \(reps)\(rpe)"
    }
  }

  let exercises: [Exercise]

  init(
    presentation: TodayWorkoutPresentation, addedDrafts: [TodayWorkoutSetRowDraft],
    unit: UnitPreference
  ) {
    var groups = presentation.exercises.map { exercise in
      Exercise(
        id: exercise.id, name: exercise.name, number: exercise.stableIndex + 1,
        isAdded: false, prescribedCount: exercise.prescribedRows.count,
        loggedCount: exercise.prescribedRows.count { $0.draft.completed || $0.draft.failed },
        rows: exercise.rows.filter { !$0.draft.isExtra || $0.draft.completed || $0.draft.failed }
          .map { Row(draft: $0.draft, unit: unit) })
    }
    var seen: Set<UUID> = []
    for draft in addedDrafts where draft.isStudentAdded && seen.insert(draft.exerciseID).inserted {
      let rows = addedDrafts.filter { $0.isStudentAdded && $0.exerciseID == draft.exerciseID }
      groups.append(
        Exercise(
          id: draft.exerciseID, name: draft.displayExerciseName, number: groups.count + 1,
          isAdded: true, prescribedCount: 0,
          loggedCount: rows.count { $0.completed || $0.failed },
          rows: rows.map { Row(draft: $0, unit: unit) }))
    }
    exercises = groups
  }
}
