import CoreModels
import DesignSystem
import SwiftUI

struct PlanHandoffSubtitle: View {
  let summary: StudentPlanHandoff.Entry
  let preview: Bool
  @Environment(\.locale) private var locale

  var body: some View {
    Text(
      StudentStrings.replacing(
        .handoffPlanWeeks,
        values: [summary.name, String(summary.weeks)], locale: locale)
        + (preview
          ? " · " + StudentStrings.localized(.handoffStartsAfterCurrent, locale: locale) : "")
    )
    .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
    .foregroundStyle(Color.MeetPR.textSecondary)
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct PlanHandoffNotice: View {
  let onDismiss: () -> Void
  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Text(StudentStrings.localized(.handoffStarted))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: MeetPRSpacing.zero)
      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .frame(
            minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(StudentStrings.localized(.handoffDismiss))
    }
    .foregroundStyle(Color.MeetPR.goldText)
    .padding(.leading, MeetPRSpacing.space3)
    .background(Color.MeetPR.gold200.opacity(0.3), in: .rect(cornerRadius: MeetPRRadius.card))
  }
}

struct PlanHandoffPreview: View {
  let day: StudentPlanDay
  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
      HStack(alignment: .firstTextBaseline) {
        Text(
          "W\(day.weekNumber)D\(day.dayOfWeek) · "
            + StudentStrings.replacing(
              .handoffExerciseCount, values: [String(day.exercises.count)])
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        Spacer()
        Text(StudentStrings.localized(.handoffPreviewOnly))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      ForEach(day.exercises) { exercise in
        VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
          Text(exercise.exercise.name)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
          ForEach(exercise.prescribedSets) { set in
            Text(
              StudentFormatting.prescribed(set)
                + (set.isLegacyPrescription
                  ? set.rpe.map { " · RPE " + StudentFormatting.decimal($0) } ?? "" : "")
            )
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textSecondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MeetPRSpacing.space2)
      }
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
  }
}

struct PlanHandoffReturnDock: View {
  let remaining: Int
  let onReturn: () -> Void
  var body: some View {
    VStack(spacing: MeetPRSpacing.space2) {
      Text(StudentStrings.replacing(.handoffRemaining, values: [String(remaining)]))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Button(action: onReturn) {
        Text(StudentStrings.localized(.handoffReturn))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
          .contentShape(.rect)
      }
      .foregroundStyle(Color.MeetPR.textPrimary)
      .buttonStyle(PressScaleButtonStyle())
      .overlay { RoundedRectangle(cornerRadius: MeetPRRadius.card).stroke(Color.MeetPR.textMuted) }
    }
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.vertical, MeetPRSpacing.space3)
    .background(Color.MeetPR.bgBase)
  }
}
