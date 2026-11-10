import CoreModels
import DesignSystem
import SwiftUI

struct AllDayExerciseBlock: View {
  let group: AllDayExercise
  let note: String
  let expanded: Bool
  let hidesName: Bool
  let viewModel: TodayWorkoutViewModel?
  let editable: Bool
  let onExpand: () -> Void
  let onVideo: (TodayWorkoutSetRowDraft) -> Void
  let onNote: (TodayWorkoutSetRowDraft) -> Void
  let onRemove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      AllDayExerciseHeader(
        group: group, expanded: expanded, hidesName: hidesName,
        unit: viewModel?.onboardingProfile?.unitPreference ?? .kg,
        editable: editable, writing: viewModel?.allDayWriting == true,
        onExpand: onExpand,
        onComplete: { Task { _ = await viewModel?.toggleAllDayExercise(group.id) } })
      if expanded {
        if !note.isEmpty {
          Text(StudentStrings.replacing(.allDayCoachNote, values: [note]))
            .lineLimit(1)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.goldText)
        }
        VStack(spacing: 0) {
          ForEach(group.rows) { draft in
            AllDaySetRow(
              draft: draft, viewModel: viewModel, editable: editable, onVideo: { onVideo(draft) })
            if draft.id != group.rows.last?.id { Divider().overlay(Color.MeetPR.borderSubtle) }
          }
        }
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: 12))
        .clipShape(.rect(cornerRadius: 12))
        if editable, let first = group.rows.first {
          HStack {
            Button(StudentStrings.localized(.addedAddSet), systemImage: "plus") {
              if first.isStudentAdded {
                viewModel?.addStudentSet(exerciseID: first.exerciseID)
              } else {
                viewModel?.addExtraSet(exerciseID: group.id)
              }
            }
            .disabled(
              first.isStudentAdded
                ? group.rows.count >= StudentAddedRows.limit
                : group.rows.filter(\.isExtra).count >= StudentAddedRows.limit)
            Spacer()
            Button(StudentStrings.askCoach, systemImage: "text.bubble") { onNote(first) }
              .accessibilityIdentifier("allDay.note.\(group.id)")
          }
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.goldText)
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          if first.isStudentAdded {
            Button(StudentStrings.localized(.addedRemove), role: .destructive, action: onRemove)
              .font(.caption)
          }
        }
      }
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .buttonStyle(.plain)
  }
}

private struct AllDayExerciseHeader: View {
  let group: AllDayExercise
  let expanded: Bool
  let hidesName: Bool
  let unit: UnitPreference
  let editable: Bool
  let writing: Bool
  let onExpand: () -> Void
  let onComplete: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Button(action: onExpand) {
        HStack(spacing: MeetPRSpacing.space2) {
          Text(hidesName ? "" : name)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
            .foregroundStyle(
              group.node == .completed
                ? Color.MeetPR.textSecondary : Color.MeetPR.textPrimary
            )
            .lineLimit(2)
            .frame(
              minWidth: MeetPRFontMetrics.size15 * 4,
              maxWidth: .infinity, alignment: .leading)
          AllDaySummaryValues(summary: AllDayExerciseSummary.build(rows: group.rows, unit: unit))
            .layoutPriority(1)
          Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
        .frame(minHeight: 48)
        .contentShape(.rect)
      }
      .accessibilityLabel(name)
      .accessibilityValue(StudentStrings.localized(expanded ? .allDayExpanded : .allDayCollapsed))
      .accessibilityIdentifier("allDay.expand.\(group.id)")
      if editable {
        Button(action: onComplete) {
          Circle()
            .fill(group.node == .completed ? Color.MeetPR.success : Color.MeetPR.bgBase)
            .overlay {
              Circle().strokeBorder(
                Color.MeetPR.textSecondary,
                lineWidth: group.node == .completed ? 0 : 1.5)
              if group.node == .completed {
                Image(systemName: "checkmark").foregroundStyle(Color.MeetPR.inkOnCTAFill)
              }
            }
            .frame(width: 30, height: 30)
            .frame(minHeight: MeetPRSpacing.minimumHitTarget)
        }
        .disabled(writing)
        .accessibilityLabel(
          StudentStrings.localized(
            group.node == .completed ? .allDayUndoExercise : .allDayFinishExercise)
        )
        .accessibilityIdentifier("allDay.complete.\(group.id)")
      }
    }
    .padding(.horizontal, MeetPRSpacing.space1)
    .background(
      expanded ? Color.MeetPR.goldRGB.opacity(0.10) : .clear,
      in: .rect(cornerRadius: 12)
    )
    .overlay {
      if expanded {
        RoundedRectangle(cornerRadius: 12).strokeBorder(Color.MeetPR.gold500, lineWidth: 1)
      }
    }
  }

  private var name: String {
    let name = group.rows.first?.displayExerciseName ?? ""
    return name
      + (group.rows.first?.isStudentAdded == true
        ? " · " + StudentStrings.localized(.addedAdded) : "")
  }
}

private struct AllDaySummaryValues: View {
  let summary: AllDayExerciseSummary

  var body: some View {
    let text = summary.segments.enumerated().reduce(Text("")) { result, pair in
      let segment = pair.element
      return result
        + Text(pair.offset > 0 ? " · " : "").foregroundStyle(Color.MeetPR.textSecondary)
        + Text(segment.reps + "  ")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(
          segment.shortReps
            ? Color.MeetPR.danger
            : segment.repsChanged ? Color.MeetPR.goldText : Color.MeetPR.textSecondary)
        + Text(segment.load)
        .font(
          .MeetPR.body(
            size: segment.intensityOnly
              ? MeetPRFontMetrics.size13 : MeetPRFontMetrics.size15, weight: .bold)
        )
        .foregroundStyle(
          segment.intensityOnly || segment.loadChanged
            ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
    }
    text.monospacedDigit()
      .multilineTextAlignment(.trailing)
      .fixedSize(horizontal: false, vertical: true)
  }
}
