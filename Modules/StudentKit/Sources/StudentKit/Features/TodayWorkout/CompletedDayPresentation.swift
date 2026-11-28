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
    let videoFailed: Bool
    let failedAttachment: VideoAttachment?
    let badge: VideoBadgeInfo

    init(
      draft: TodayWorkoutSetRowDraft, unit: UnitPreference, videos: [StudentVideo],
      local: [VideoAttachment], trainingDate: Date
    ) {
      let attachment = VideoDeliveryPresentation.attachment(
        for: draft, trainingDate: trainingDate, in: local)
      failedAttachment = attachment.flatMap { VideoDeliveryPresentation.hasFailure($0) ? $0 : nil }
      videoFailed = failedAttachment != nil
      video = CompletedSetVideo.resolve(setLogID: draft.loggedSetID, videos: videos, local: local)
      badge = draft.videoBadge
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
      let rpe =
        draft.actualRIR.map { " · RIR \($0)" } ?? draft.actualRPE.map {
          " · RPE \(StudentFormatting.decimal($0))"
        } ?? ""
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
        .map {
          Row(
            draft: $0.draft, unit: unit, videos: videos, local: local,
            trainingDate: presentation.day.scheduledDate)
        }
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
          rows: rows.map {
            Row(
              draft: $0, unit: unit, videos: videos, local: local,
              trainingDate: presentation.day.scheduledDate)
          },
          reservesVideoSpace: TrainingHistoryVideoPresentation.reservesVideoSpace(
            setLogIDs: rows.map(\.loggedSetID), videos: videos, local: local)))
    }
    exercises = groups
  }
}

extension TodayWorkoutSetRowDraft {
  var videoBadge: VideoBadgeInfo {
    videoBadge(
      weight: actualWeight, reps: actualReps, rpe: videoBadgeRPE,
      setNumber: prescribed.setIndex + 1)
  }

  func videoBadge(weight: Decimal?, reps: Int?, rpe: Decimal?, setNumber: Int) -> VideoBadgeInfo {
    let addedWeight = prescribed.isBodyweight && weight == 0 ? nil : weight
    return VideoBadgeInfo(
      exerciseName: displayExerciseName,
      weightKg: addedWeight.map { NSDecimalNumber(decimal: $0).doubleValue },
      reps: reps, rpe: rpe.map { NSDecimalNumber(decimal: $0).doubleValue },
      setOrdinal: setNumber)
  }
}
