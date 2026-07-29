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
      exercise: "硬拉",
      meta: "上次 170kg×3 @8 · 最佳 175kg×3 @8.5",
      note: "注意启动时股四的蹬地",
      collapsed: false,
      sets: mixedExerciseSets
    )
    ExerciseCard(
      exercise: "节奏卧推",
      meta: "上次 87.5kg×2 @6 · 最佳 90kg×2 @6",
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
      exercise: "硬拉",
      meta: "上次 170kg×3 @8 · 最佳 175kg×3 @8.5",
      note: "注意启动时股四的蹬地",
      collapsed: false,
      sets: mixedExerciseSets
    )
    ExerciseCard(
      exercise: "节奏卧推",
      meta: "上次 87.5kg×2 @6 · 最佳 90kg×2 @6",
      note: "",
      collapsed: true,
      sets: finishedExerciseSets
    )
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
