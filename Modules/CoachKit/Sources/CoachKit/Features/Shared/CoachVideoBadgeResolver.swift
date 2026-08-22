import ChatUI
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts

enum CoachVideoBadgeResolver {
  static func studentVideo(
    _ video: StudentVideo,
    planDays: [StudentPlanDay],
    logs: [StudentSetLog],
    coachName: String?
  ) -> VideoBadgeInfo {
    let exercise = video.planExerciseID.flatMap { planExerciseID in
      planDays.lazy.flatMap(\.exercises).first { $0.id == planExerciseID }
    }
    let log = video.setLogID.flatMap { setLogID in
      logs.first { $0.id == setLogID }
    }
    return VideoBadgeInfo(
      exerciseName: exercise.map { CoachLocalization.exerciseName($0.exercise) },
      weightKg: log.map { NSDecimalNumber(decimal: $0.weightKg).doubleValue },
      reps: log?.reps,
      rpe: log?.rpe.map { NSDecimalNumber(decimal: $0).doubleValue },
      setOrdinal: log.map {
        SetIndexDisplay.number(forZeroBasedIndex: $0.setIndex)
      },
      coachName: coachName
    )
  }

  static func pendingVideo(
    _ item: PendingVideoItem,
    setInfo: VideoSetInfo?,
    coachName: String?
  ) -> VideoBadgeInfo {
    VideoBadgeInfo(
      exerciseName: item.exerciseName.map { CoachLocalization.exerciseName($0) },
      weightKg: setInfo?.weightKg,
      reps: setInfo?.reps,
      rpe: setInfo?.rpe,
      setOrdinal: setInfo?.displaySetNumber,
      coachName: coachName
    )
  }
}
