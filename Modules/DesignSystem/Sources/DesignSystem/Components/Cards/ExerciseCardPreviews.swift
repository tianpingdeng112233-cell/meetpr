import SwiftUI

private let mixedExerciseSets = [
  ExerciseSetRecord(
    index: 1, weight: 175, reps: 3, rpe: 8.5, status: .done, videoState: .uploaded),
  ExerciseSetRecord(
    index: 2, weight: 175, reps: 3, rpe: 8.5, status: .failed, videoState: .failed),
  ExerciseSetRecord(
    index: 3, weight: 175, reps: 3, rpe: 8.5, status: .pending, videoState: .none),
]

private let finishedExerciseSets = [
  ExerciseSetRecord(
    index: 1, weight: 90, reps: 2, rpe: 6, status: .done, videoState: .uploaded),
  ExerciseSetRecord(
    index: 2, weight: 90, reps: 2, rpe: 6, status: .failed, videoState: .uploaded),
]

#Preview("ExerciseCard · Expanded + Summary · Dark") {
  VStack(spacing: MeetPRSpacing.point10) {
    ExerciseCard(
      exercise: DesignSystemStrings.deadlift,
      meta: DesignSystemStrings.previousBestDeadlift,
      note: DesignSystemStrings.deadliftNote,
      collapsed: false,
      sets: mixedExerciseSets
    )
    ExerciseCard(
      exercise: DesignSystemStrings.tempoBench,
      meta: DesignSystemStrings.previousBestTempoBench,
      note: "",
      collapsed: true,
      sets: finishedExerciseSets
    )
  }
  .padding()
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}
#Preview("ExerciseCard · Expanded + Summary · Light") {
  VStack(spacing: MeetPRSpacing.point10) {
    ExerciseCard(
      exercise: DesignSystemStrings.deadlift,
      meta: DesignSystemStrings.previousBestDeadlift,
      note: DesignSystemStrings.deadliftNote,
      collapsed: false,
      sets: mixedExerciseSets
    )
    ExerciseCard(
      exercise: DesignSystemStrings.tempoBench,
      meta: DesignSystemStrings.previousBestTempoBench,
      note: "",
      collapsed: true,
      sets: finishedExerciseSets
    )
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
