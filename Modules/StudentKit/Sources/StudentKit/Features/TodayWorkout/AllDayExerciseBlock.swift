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
        previousEffort: group.rows.first.flatMap { viewModel?.previousAllDayEffort(for: $0) },
        editable: editable, writing: viewModel?.allDayWriting == true,
        onExpand: onExpand,
        onComplete: { Task { _ = await viewModel?.toggleAllDayExercise(group.id) } })
      if expanded {
        if !note.isEmpty {
          Text(StudentStrings.replacing(.allDayCoachNote, values: [note]))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
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
            Button {
              onNote(first)
            } label: {
              Image(systemName: "text.bubble")
                .frame(
                  width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
            }
            .accessibilityLabel(StudentStrings.localized(.allDayAskCoach))
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
  let previousEffort: ActualEffortMode?
  let editable: Bool
  let writing: Bool
  let onExpand: () -> Void
  let onComplete: () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Button(action: onExpand) {
        AllDayExerciseLabel(
          name: hidesName ? "" : name, completed: group.node == .completed,
          expanded: expanded, editable: editable,
          summary: AllDayExerciseSummary.build(
            rows: group.rows, unit: unit, previousEffort: previousEffort)
        )
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
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(group.node == .current ? Color.MeetPR.goldRGB.opacity(0.10) : .clear)
    }
    .overlay {
      if expanded || group.node == .current {
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

private struct AllDayExerciseLabel: View {
  let name: String
  let completed: Bool
  let expanded: Bool
  let editable: Bool
  let summary: AllDayExerciseSummary

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      HStack(spacing: MeetPRSpacing.space2) {
        AllDayExerciseName(name: name, completed: completed)
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
        if editable { Color.clear.frame(width: 30, height: 1) }
      }
      .frame(minHeight: 30)
      AllDaySummaryValues(summary: summary)
        .padding(.trailing, 44)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, MeetPRSpacing.space1)
  }
}

private struct AllDayExerciseName: View {
  let name: String
  let completed: Bool

  var body: some View {
    Text(name)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
      .foregroundStyle(completed ? Color.MeetPR.textSecondary : Color.MeetPR.textPrimary)
      .lineLimit(2)
      .frame(minWidth: MeetPRFontMetrics.size15 * 4, maxWidth: .infinity, alignment: .leading)
  }
}

private struct AllDaySummaryValues: View {
  let summary: AllDayExerciseSummary

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      ForEach(summary.segments.indices, id: \.self) { index in
        let segment = summary.segments[index]
        AllDaySummaryColumns {
          Text(segment.reps.isEmpty ? "—" : segment.reps)
            .foregroundStyle(
              segment.shortReps
                ? Color.MeetPR.danger
                : segment.repsChanged ? Color.MeetPR.goldText : Color.MeetPR.textPrimary
            )
            .accessibilityIdentifier("allDay.summary.reps.\(index)")
          Text(segment.load.replacing(" / ", with: "/"))
            .foregroundStyle(
              segment.weightChanged ? Color.MeetPR.goldText : Color.MeetPR.textPrimary
            )
            .accessibilityIdentifier("allDay.summary.load.\(index)")
          Text(
            (segment.effort == "—" ? "RPE —" : segment.effort).replacing(" / ", with: "/")
              .replacing("RPE ", with: "RPE\u{00a0}")
              .replacing("RIR ", with: "RIR\u{00a0}")
          )
          .foregroundStyle(Color.MeetPR.goldText)
          .accessibilityIdentifier("allDay.summary.effort.\(index)")
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .monospacedDigit()
        .multilineTextAlignment(.leading)
      }
    }
  }
}

/// Every exercise receives the same column proportions, independent of its values.
private struct AllDaySummaryColumns: Layout {
  private let proportions: [CGFloat] = [0.87, 1.79, 1.34]
  private let spacing: CGFloat = MeetPRSpacing.space1

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? 300
    let widths = columnWidths(width)
    let height =
      zip(subviews, widths).map { view, width in
        view.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
      }.max() ?? 0
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var x = bounds.minX
    for (view, width) in zip(subviews, columnWidths(bounds.width)) {
      view.place(
        at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
        proposal: ProposedViewSize(width: width, height: nil))
      x += width + spacing
    }
  }

  private func columnWidths(_ width: CGFloat) -> [CGFloat] {
    let available = max(0, width - spacing * 2)
    return proportions.map { available * $0 / proportions.reduce(0, +) }
  }
}
