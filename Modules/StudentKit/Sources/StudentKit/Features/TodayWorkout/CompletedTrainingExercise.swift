import CoreModels
import DesignSystem
import SwiftUI

struct CompletedTrainingExercise: View {
  let exercise: TodayWorkoutPresentation.Exercise
  @Binding var collapsed: Bool
  let viewModel: TodayWorkoutViewModel?
  let previousLogs: [Int: StudentSetLog]
  let onEdit: (TodayWorkoutPresentation.Row) -> Void
  let onVideoAction: (TodayWorkoutPresentation.Row) -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      Button {
        collapsed.toggle()
      } label: {
        HStack(spacing: MeetPRSpacing.point10) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: MeetPRFontMetrics.size22))
            .foregroundStyle(.white, Color.MeetPR.success)
          Text(exercise.name)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(exercise.trainingCompletedText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          Image(systemName: collapsed ? "chevron.right" : "chevron.down")
            .font(.system(size: MeetPRFontMetrics.size12, weight: .semibold))
        }
        .foregroundStyle(colorScheme == .dark ? Color.MeetPR.successSoft : Color.MeetPR.textPrimary)
        .padding(.horizontal, MeetPRSpacing.point14)
        .frame(minHeight: MeetPRSpacing.point48)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(exercise.trainingCompletedAccessibility)
      .accessibilityValue(collapsed ? DesignSystemStrings.collapsed : DesignSystemStrings.expanded)
      .accessibilityIdentifier("training.completed.\(exercise.stableIndex)")

      if !collapsed {
        Group {
          if exercise.rows.first?.draft.isAccessory == true, let viewModel {
            VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
              if !exercise.note.isEmpty {
                Text(exercise.note)
                  .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
                  .foregroundStyle(Color.MeetPR.textSecondary)
              }
              AccessoryLogCard(
                exercise: exercise, viewModel: viewModel,
                unit: viewModel.onboardingProfile?.unitPreference ?? .kg,
                previousLogs: previousLogs, onEdit: onEdit)
            }
          } else {
            CompletedTrainingSetTable(
              exercise: exercise, onEdit: onEdit, onVideoAction: onVideoAction)
          }
        }
        .padding(MeetPRSpacing.space3)
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.control))
        .padding([.horizontal, .bottom], MeetPRSpacing.space3)
      }
    }
    .background(Color.MeetPR.successTint, in: .rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct CompletedTrainingSetTable: View {
  let exercise: TodayWorkoutPresentation.Exercise
  let onEdit: (TodayWorkoutPresentation.Row) -> Void
  let onVideoAction: (TodayWorkoutPresentation.Row) -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      HStack(spacing: MeetPRSpacing.zero) {
        Text("#").frame(width: 22, alignment: .leading)
        Text(StudentStrings.localized(.setEntrySheet001)).frame(
          maxWidth: .infinity, alignment: .leading)
        Text(StudentStrings.localized(.setEntrySheet003)).frame(maxWidth: .infinity)
        Text("RPE").frame(maxWidth: .infinity)
        Color.clear.frame(width: 64)
      }
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
      .foregroundStyle(Color.MeetPR.textDim)
      .padding(.horizontal, MeetPRSpacing.point14)
      .padding(.vertical, MeetPRSpacing.point6)
      ForEach(exercise.rows) { row in
        let record = row.record
        SetRow(
          index: record.index, weight: record.weight, reps: record.reps, rpe: record.rpe,
          status: record.status, videoState: record.videoState,
          indexAccessibilityIdentifier: record.indexAccessibilityIdentifier,
          prescriptionDisplay: record.prescriptionDisplay,
          onEdit: { onEdit(row) }, onVideoAction: { onVideoAction(row) })
      }
      if !exercise.note.isEmpty {
        Text(exercise.note)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(MeetPRSpacing.space3)
      }
    }
  }
}
