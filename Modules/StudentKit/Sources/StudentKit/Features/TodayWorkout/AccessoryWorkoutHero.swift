import CoreModels
import DesignSystem
import SwiftUI

struct AccessoryWorkoutHero: View {
  let exercise: TodayWorkoutPresentation.Exercise
  let exerciseTotal: Int
  let accessoryViewModel: TodayWorkoutViewModel
  let previousLogs: [Int: StudentSetLog]
  let showsAskCoach: Bool
  let isPreparingAskCoach: Bool
  let onAskCoach: () -> Void
  let onEdit: (TodayWorkoutPresentation.Row) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      TodayWorkoutRecordingHeader(
        exerciseName: exercise.name, showsAskCoach: showsAskCoach,
        isPreparingAskCoach: isPreparingAskCoach, onAskCoach: onAskCoach)
      Text(
        [
          StudentStrings.localized(.accessoryAccessory),
          exercise.rows.allSatisfy {
            AccessoryRow(draft: $0.draft, previous: nil, unit: .kg).isBodyweight
          } ? StudentStrings.localized(.accessoryBodyweight) : nil,
          exercise.prescriptionSummary ?? exercise.cardSubtitle,
          StudentStrings.replacing(
            .todayWorkoutPresentation003,
            values: [String(exercise.stableIndex + 1), String(exerciseTotal)]
          )
          .trimmingCharacters(in: CharacterSet(charactersIn: " ·")),
        ].compactMap { $0 }.joined(separator: " · ")
      )
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textMuted)
      .lineLimit(1)
      if let note = CoachNoteDisplay.heroExerciseNote(isEditable: true, notes: exercise.note) {
        HeroCoachNote(note: note)
      }
      AccessoryLogCard(
        exercise: exercise, viewModel: accessoryViewModel,
        unit: accessoryViewModel.onboardingProfile?.unitPreference ?? .kg,
        previousLogs: previousLogs, onEdit: onEdit
      )
      .id(exercise.id)
    }
  }
}
