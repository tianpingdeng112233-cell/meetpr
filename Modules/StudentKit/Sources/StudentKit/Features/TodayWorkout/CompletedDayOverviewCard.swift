import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

struct CompletedDayOverviewCard: View {
  let presentation: TodayWorkoutPresentation
  let drafts: [TodayWorkoutSetRowDraft]
  let unit: UnitPreference
  let canUndo: Bool
  let onUndo: () -> Void
  @Environment(CompletedVideoReplayModel.self) private var replay: CompletedVideoReplayModel?
  @State private var expanded: Set<UUID> = []
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      let headerLayout =
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: MeetPRSpacing.space2))
        : AnyLayout(HStackLayout(spacing: MeetPRSpacing.space2))
      headerLayout {
        Text(StudentStrings.localized(.todayWorkoutScreen017))
          .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
          .frame(maxWidth: .infinity, alignment: .leading)
        Label(StudentStrings.localized(.todayWorkoutScreen009), systemImage: "checkmark")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
          .padding(.horizontal, MeetPRSpacing.point13)
          .padding(.vertical, MeetPRSpacing.space2)
          .background(Color.MeetPR.successTint, in: .capsule)
      }
      Text(
        StudentStrings.replacing(
          .todayWorkoutScreen018, values: [String(presentation.exercises.count)])
          + StudentStrings.replacing(
            .todayWorkoutScreen019,
            values: [String(presentation.exercises.flatMap(\.prescribedRows).count)])
      )
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textTertiary)

      let overview = CompletedDayPresentation(
        presentation: presentation, addedDrafts: drafts, unit: unit, videos: replay?.videos ?? [],
        local: replay?.local ?? [])
      ForEach(overview.exercises) { exercise in
        CompletedDayExerciseRow(
          exercise: exercise, expanded: expanded.contains(exercise.id)
        ) {
          if !expanded.insert(exercise.id).inserted { expanded.remove(exercise.id) }
        }
      }
      if canUndo {
        Button(StudentStrings.localized(.todayWorkoutScreen023), action: onUndo)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .accessibilityIdentifier("training.completedDay.undo")
      }
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .padding(MeetPRSpacing.space4)
    .padding(.leading, MeetPRSpacing.point3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.bgInset)
    .overlay(alignment: .leading) {
      Color.MeetPR.success.frame(width: MeetPRSpacing.point3)
    }
    .clipShape(
      .rect(
        topLeadingRadius: 0, bottomLeadingRadius: 0,
        bottomTrailingRadius: MeetPRRadius.card, topTrailingRadius: MeetPRRadius.card)
    )
    .overlay {
      UnevenRoundedRectangle(
        topLeadingRadius: 0, bottomLeadingRadius: 0,
        bottomTrailingRadius: MeetPRRadius.card, topTrailingRadius: MeetPRRadius.card
      ).stroke(Color.MeetPR.borderStrong, lineWidth: 1)
    }
    .accessibilityIdentifier("training.completedDay.card")
  }
}

private struct CompletedDayExerciseRow: View {
  let exercise: CompletedDayPresentation.Exercise
  let expanded: Bool
  let onToggle: () -> Void
  @Environment(CompletedVideoReplayModel.self) private var replay: CompletedVideoReplayModel?
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      Button(action: onToggle) {
        HStack(spacing: MeetPRSpacing.point11) {
          Group {
            if exercise.isComplete {
              Image(systemName: "checkmark").foregroundStyle(Color.MeetPR.success)
            } else {
              Text(exercise.number.formatted()).foregroundStyle(Color.MeetPR.goldText)
            }
          }
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
          .frame(width: MeetPRSpacing.point22, height: MeetPRSpacing.point22)
          .background(
            exercise.isComplete ? Color.MeetPR.successTint : Color.MeetPR.goldRGB.opacity(0.12)
          )
          .clipShape(.rect(cornerRadius: MeetPRSpacing.point7))
          let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: MeetPRSpacing.space1))
            : AnyLayout(HStackLayout(spacing: MeetPRSpacing.space2))
          layout {
            Text(exercise.name)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
              .frame(maxWidth: .infinity, alignment: .leading)
            Text(exercise.summary)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        .padding(.horizontal, MeetPRSpacing.point13)
        .padding(.vertical, MeetPRSpacing.point11)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(exercise.name + ", " + exercise.summary)
      .accessibilityValue(expanded ? DesignSystemStrings.expanded : DesignSystemStrings.collapsed)
      .accessibilityIdentifier("training.completedDay.exercise.\(exercise.number)")
      if expanded {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          ForEach(exercise.rows) { row in
            HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
              Text(row.isExtra ? StudentStrings.localized(.addedExtra) : row.number.formatted())
                .foregroundStyle(Color.MeetPR.textMuted)
              Text(row.result)
                .foregroundStyle(row.failed ? Color.MeetPR.danger : Color.MeetPR.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
              CompletedSetVideoButton(
                video: row.video, upload: replay?.uploadState(setLogID: row.setLogID),
                number: row.number, reservesSpace: exercise.reservesVideoSpace
              ) { video in
                replay?.open(video, badge: row.badge)
              }
            }
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
          }
        }
        .modifier(CompletedVideoHitRouting())
        .padding(.horizontal, MeetPRSpacing.point13)
        .padding(.bottom, MeetPRSpacing.point11)
      }
    }
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.control))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
    }
  }
}
