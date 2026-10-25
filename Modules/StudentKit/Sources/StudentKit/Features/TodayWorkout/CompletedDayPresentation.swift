import ChatUI
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
    let reservesVideoSpace: Bool

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
    let setLogID: UUID?
    let isExtra: Bool
    let failed: Bool
    let result: String
    let video: CompletedSetVideo?
    let badge: VideoBadgeInfo

    init(
      draft: TodayWorkoutSetRowDraft, unit: UnitPreference, videos: [StudentVideo],
      local: [VideoAttachment]
    ) {
      video = CompletedSetVideo.resolve(setLogID: draft.loggedSetID, videos: videos, local: local)
      badge = VideoBadgeInfo(
        exerciseName: draft.displayExerciseName,
        weightKg: draft.actualWeight.map { NSDecimalNumber(decimal: $0).doubleValue },
        reps: draft.actualReps,
        rpe: draft.actualRPE.map { NSDecimalNumber(decimal: $0).doubleValue },
        setOrdinal: draft.prescribed.setIndex + 1)
      id = draft.id
      setLogID = draft.loggedSetID
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
    unit: UnitPreference, videos: [StudentVideo] = [], local: [VideoAttachment] = []
  ) {
    var groups = presentation.exercises.map { exercise in
      let rows = exercise.rows
        .filter { !$0.draft.isExtra || $0.draft.completed || $0.draft.failed }
        .map { Row(draft: $0.draft, unit: unit, videos: videos, local: local) }
      return Exercise(
        id: exercise.id, name: exercise.name, number: exercise.stableIndex + 1,
        isAdded: false, prescribedCount: exercise.prescribedRows.count,
        loggedCount: exercise.prescribedRows.count { $0.draft.completed || $0.draft.failed },
        rows: rows,
        reservesVideoSpace: TrainingHistoryVideoPresentation.reservesVideoSpace(
          setLogIDs: rows.map(\.setLogID), videos: videos, local: local))
    }
    var seen: Set<UUID> = []
    for draft in addedDrafts where draft.isStudentAdded && seen.insert(draft.exerciseID).inserted {
      let rows = addedDrafts.filter { $0.isStudentAdded && $0.exerciseID == draft.exerciseID }
      groups.append(
        Exercise(
          id: draft.exerciseID, name: draft.displayExerciseName, number: groups.count + 1,
          isAdded: true, prescribedCount: 0,
          loggedCount: rows.count { $0.completed || $0.failed },
          rows: rows.map { Row(draft: $0, unit: unit, videos: videos, local: local) },
          reservesVideoSpace: TrainingHistoryVideoPresentation.reservesVideoSpace(
            setLogIDs: rows.map(\.loggedSetID), videos: videos, local: local)))
    }
    exercises = groups
  }
}
