import CoreModels
import DesignSystem
import SwiftUI

struct AllDaySetRow: View {
  let draft: TodayWorkoutSetRowDraft
  let viewModel: TodayWorkoutViewModel?
  let editable: Bool
  let onVideo: () -> Void
  @Environment(WorkoutKeypadSession.self) private var keypad: WorkoutKeypadSession?
  @State private var showsRemoval = false
  @Environment(VideoAttachmentViewModel.self) private var uploads: VideoAttachmentViewModel?
  @Environment(CompletedVideoReplayModel.self) private var replay: CompletedVideoReplayModel?

  private var editing: Bool { keypad?.current?.rowID == draft.id }
  private var shortReps: Bool {
    guard let actual = draft.actualReps, let target = draft.prescribed.reps else { return false }
    return actual < target
  }

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Text(String(SetDisplayNumber.number(for: draft)))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(width: 20)
        .accessibilityIdentifier("todayWorkout.set.\(draft.id.uuidString).number")
      if editing {
        AllDayInlineEditor(draft: draft, viewModel: viewModel, keypad: keypad)
      } else {
        AllDaySetValues(
          draft: draft, shortReps: shortReps,
          previousEffort: viewModel?.previousAllDayEffort(for: draft),
          unit: viewModel?.onboardingProfile?.unitPreference ?? .kg,
          editable: editable, onEdit: openEditor
        )
      }
      AllDaySetVideoButton(
        draft: draft, trainingDate: viewModel?.currentDay?.scheduledDate ?? .distantPast,
        editable: editable, uploads: uploads, replay: replay, onEditVideo: onVideo)
      if case .percentage(let value) = draft.prescribed.intensity {
        Text(StudentFormatting.decimal(value) + "%")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .fixedSize()
      }
    }
    .contextMenu {
      if editable, draft.isExtra || draft.isStudentAdded {
        Button(StudentStrings.localized(.addedRemove), role: .destructive) { showsRemoval = true }
      }
    }
    .confirmationDialog(StudentStrings.localized(.addedConfirmSet), isPresented: $showsRemoval) {
      Button(StudentStrings.localized(.addedRemove), role: .destructive) {
        Task { _ = await viewModel?.removeStudentRow(id: draft.id) }
      }
    }
    .padding(.horizontal, MeetPRSpacing.space2)
    .padding(.vertical, editing ? MeetPRSpacing.space2 : 0)
    .background(
      editing
        ? Color.MeetPR.goldRGB.opacity(0.10)
        : shortReps ? Color.MeetPR.dangerSoft : Color.MeetPR.surfaceCard)
  }

  private func openEditor(_ field: MeetPRNumberPad.Field) {
    guard editable, let viewModel, let keypad else { return }
    keypad.openAllDay(draft: draft, viewModel: viewModel, field: field)
  }
}

private struct AllDaySetValues: View {
  let draft: TodayWorkoutSetRowDraft
  let shortReps: Bool
  let previousEffort: ActualEffortMode?
  let unit: UnitPreference
  let editable: Bool
  let onEdit: (MeetPRNumberPad.Field) -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space1) {
      Button {
        onEdit(.weight)
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space1) {
          Text(draft.actualWeight.map { UnitDisplay.weightText(kg: $0, unit: unit) } ?? "—")
            .foregroundStyle(
              weightChanged || (draft.isHistoryWeightPrefill == true && !draft.hasSavedRecord)
                ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
          if draft.actualWeight != nil {
            Text(UnitDisplay.weightUnitSuffix(unit)).font(
              .MeetPR.body(size: MeetPRFontMetrics.size12)
            )
            .foregroundStyle(Color.MeetPR.textSecondary)
          }
          if weightChanged, let original = draft.prescribed.weightKg {
            Text(
              StudentStrings.replacing(
                .allDayOriginal, values: [UnitDisplay.weightText(kg: original, unit: unit)])
            )
            .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textSecondary)
          }
          Text("×").foregroundStyle(Color.MeetPR.textSecondary)
          VStack(alignment: .leading, spacing: 2) {
            Text(repsText)
              .foregroundStyle(
                shortReps
                  ? Color.MeetPR.danger
                  : repsChanged ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
            if repsChanged, let original = draft.prescribed.reps {
              AllDayOriginalValue(value: String(original))
            }
          }
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(!editable)
      .accessibilityIdentifier("allDay.row.\(draft.id)")
      Button {
        onEdit(effortField)
      } label: {
        VStack(alignment: .leading, spacing: 2) {
          Text(effortText)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(
              effortChanged ? Color.MeetPR.goldText : Color.MeetPR.textSecondary)
          if effortChanged, let originalEffort {
            AllDayOriginalValue(value: originalEffort)
          }
        }
        .frame(minHeight: 38)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(!editable)
      .accessibilityIdentifier("allDay.effort.\(draft.id)")
    }
    .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
    .monospacedDigit()
  }

  private var effortField: MeetPRNumberPad.Field {
    draft.allDayEffortMode(previous: previousEffort) == .rir ? .rir : .rpe
  }

  private var weightChanged: Bool {
    draft.prescribed.weightKg != nil && draft.actualWeight != draft.prescribed.weightKg
  }
  private var repsChanged: Bool {
    draft.prescribed.reps != nil && draft.actualReps != draft.prescribed.reps
  }
  private var repsText: String {
    let actual = draft.actualReps.map(String.init) ?? "—"
    return shortReps ? actual + "/" + String(draft.prescribed.reps ?? 0) : actual
  }
  private var effortChanged: Bool {
    switch draft.prescribed.intensity {
    case .rir(let target):
      return draft.actualRIR != target || draft.actualRPE != nil
    case .rpeRange(let low, let high):
      guard let actual = draft.actualRPE, draft.actualRIR == nil else { return true }
      return actual < low || actual > high
    default:
      return draft.actualRPE != draft.prescribed.rpe || draft.actualRIR != nil
    }
  }
  private var originalEffort: String? {
    switch draft.prescribed.intensity {
    case .rpe(let target): return "RPE \(StudentFormatting.decimal(target))"
    case .rir(let target): return "RIR \(target)"
    case .rpeRange(let low, let high):
      return "RPE \(StudentFormatting.decimal(low))–\(StudentFormatting.decimal(high))"
    default: return nil
    }
  }
  private var effortText: String {
    if let rir = draft.actualRIR { return "RIR \(rir)" }
    if let rpe = draft.actualRPE { return "RPE \(StudentFormatting.decimal(rpe))" }
    return draft.emptyEffortMode(previous: previousEffort).label + " —"
  }
}

private struct AllDayInlineEditor: View {
  let draft: TodayWorkoutSetRowDraft
  let viewModel: TodayWorkoutViewModel?
  let keypad: WorkoutKeypadSession?

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      ForEach(
        WorkoutKeypadCell.allDayCells(
          draft: draft, unit: viewModel?.onboardingProfile?.unitPreference ?? .kg,
          effortOverride: keypad?.effortField(for: draft.id)
            ?? (draft.allDayEffortMode(previous: viewModel?.previousAllDayEffort(for: draft))
              == .rir
              ? .rir : .rpe))
      ) { cell in
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          HStack(spacing: MeetPRSpacing.space2) {
            Button {
              switchEffort(cell.field == .rir ? .rpe : .rir)
            } label: {
              HStack(spacing: 0) {
                Text(cell.fieldTitle + (cell.field == .weight ? " " + (cell.unit ?? "kg") : ""))
                if draft.isAccessory, cell.field == .rpe || cell.field == .rir {
                  Image(systemName: "chevron.down")
                }
              }
              .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!draft.isAccessory || (cell.field != .rpe && cell.field != .rir))
            .accessibilityIdentifier("allDay.label.\(draft.id).\(cell.field)")
            if cell.field == .rpe || cell.field == .rir {
              EffortExplainerButton(kind: cell.field == .rir ? .rir : .rpe, isInlineHeader: true)
            }
          }
          Button {
            if let viewModel {
              keypad?.openAllDay(draft: draft, viewModel: viewModel, field: cell.field)
            }
          } label: {
            HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space1) {
              Text(
                (keypad?.current?.id == cell.id ? keypad?.previewText : cell.value).flatMap {
                  $0.isEmpty ? nil : $0
                } ?? "—"
              )
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.75)
              .foregroundStyle(
                cell.field == .weight && draft.isHistoryWeightPrefill == true
                  && !draft.hasSavedRecord
                  ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
              if cell.field == .weight, draft.isHistoryWeightPrefill == true, !draft.hasSavedRecord
              {
                Text(StudentStrings.localized(.accessoryLast))
                  .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
                  .foregroundStyle(Color.MeetPR.goldText)
                  .fixedSize()
                  .accessibilityIdentifier("allDay.previousWeight.\(draft.id)")
              }
            }
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .padding(.horizontal, MeetPRSpacing.space2)
            .background(Color.MeetPR.bgBase, in: .rect(cornerRadius: 8))
            .overlay {
              RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                  keypad?.current?.id == cell.id ? Color.MeetPR.gold500 : Color.MeetPR.borderStrong)
            }
            .background {
              if keypad?.current?.id == cell.id {
                RoundedRectangle(cornerRadius: 10).fill(Color.MeetPR.goldRGB.opacity(0.16)).padding(
                  -2)
              }
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            cell.fieldTitle + (cell.field == .weight ? " " + (cell.unit ?? "kg") : "")
          )
          .accessibilityValue(
            (keypad?.current?.id == cell.id ? keypad?.previewText : cell.value) ?? "—"
          )
          .accessibilityIdentifier("allDay.cell.\(draft.id).\(cell.field)")
        }
        .frame(maxWidth: cell.field == .weight ? .infinity : 62)
      }
    }
  }
  private func switchEffort(_ field: MeetPRNumberPad.Field) {
    guard let viewModel else { return }
    keypad?.openAllDay(draft: draft, viewModel: viewModel, field: field)
    viewModel.rememberAllDayEffort(field == .rir ? .rir : .rpe, for: draft)
  }

}

private struct AllDayOriginalValue: View {
  let value: String
  var body: some View {
    Text(StudentStrings.replacing(.allDayOriginal, values: [value]))
      .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
      .foregroundStyle(Color.MeetPR.textSecondary)
  }
}
