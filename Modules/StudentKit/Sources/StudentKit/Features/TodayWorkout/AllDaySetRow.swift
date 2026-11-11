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
  @Environment(VideoAttachmentViewModel.self) private var videos: VideoAttachmentViewModel?

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
        Button {
          openEditor()
        } label: {
          AllDaySetValues(
            draft: draft, shortReps: shortReps,
            unit: viewModel?.onboardingProfile?.unitPreference ?? .kg
          )
          .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!editable)
        .accessibilityIdentifier("allDay.row.\(draft.id)")
      }
      if editable {
        Button(action: onVideo) {
          Image(systemName: "video")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
            .foregroundStyle(cameraColor)
            .frame(width: 40, height: MeetPRSpacing.minimumHitTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StudentStrings.localized(.setVideoUploadIndicator001))
        .accessibilityIdentifier("allDay.camera.\(draft.id)")
      }
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

  private var cameraColor: Color {
    let state =
      videos?.pendingRowState(
        draftID: draft.id, trainingDate: viewModel?.currentDay?.scheduledDate ?? .distantPast,
        slot: draft.pendingVideoSlot)
      ?? draft.loggedSetID.flatMap { videos?.rowStates[$0] }
    switch state?.attachment.status {
    case .uploaded: return Color.MeetPR.success
    case .pending, .uploading: return Color.MeetPR.gold500
    case .failed: return Color.MeetPR.danger
    case nil: return Color.MeetPR.textSecondary
    }
  }

  private func openEditor() {
    guard editable, let viewModel, let keypad else { return }
    keypad.openAllDay(draft: draft, viewModel: viewModel, field: .weight)
  }
}

private struct AllDaySetValues: View {
  let draft: TodayWorkoutSetRowDraft
  let shortReps: Bool
  let unit: UnitPreference

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space1) {
      Text(draft.actualWeight.map { UnitDisplay.weightText(kg: $0, unit: unit) } ?? "—")
        .foregroundStyle(weightChanged ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
      if draft.actualWeight != nil {
        Text(UnitDisplay.weightUnitSuffix(unit)).font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      if weightChanged, let original = draft.prescribed.weightKg {
        Text(
          StudentStrings.replacing(
            .allDayOriginal, values: [UnitDisplay.weightText(kg: original, unit: unit)])
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
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
      Spacer(minLength: MeetPRSpacing.space1)
      VStack(alignment: .leading, spacing: 2) {
        Text(effortText)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(
            effortChanged ? Color.MeetPR.goldText : Color.MeetPR.textSecondary)
        if effortChanged {
          AllDayOriginalValue(value: originalEffort)
        }
      }
    }
    .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
    .monospacedDigit()
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
    if case .rir(let target) = draft.prescribed.intensity {
      return draft.actualRIR != target || draft.actualRPE != nil
    }
    return draft.actualRPE != draft.prescribed.rpe || draft.actualRIR != nil
  }
  private var originalEffort: String {
    if case .rir(let target) = draft.prescribed.intensity { return "RIR \(target)" }
    return StudentFormatting.decimal(draft.prescribed.rpe)
  }
  private var effortText: String {
    if let rir = draft.actualRIR { return "RIR \(rir)" }
    if let rpe = draft.actualRPE { return "RPE \(StudentFormatting.decimal(rpe))" }
    if case .rir = draft.prescribed.intensity { return "RIR —" }
    return "RPE —"
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
          effortOverride: keypad?.current?.field == .rir ? .rir : nil)
      ) { cell in
        Button {
          if let viewModel {
            keypad?.openAllDay(draft: draft, viewModel: viewModel, field: cell.field)
          }
        } label: {
          VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
            HStack(spacing: 0) {
              Text(cell.fieldTitle + (cell.field == .weight ? " " + (cell.unit ?? "kg") : ""))
              if draft.isAccessory, cell.field == .rpe || cell.field == .rir {
                Menu {
                  Button("RPE") { switchEffort(.rpe) }
                  Button("RIR") { switchEffort(.rir) }
                } label: {
                  Image(systemName: "chevron.down")
                }
              }
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textSecondary)
            Text(
              (keypad?.current?.id == cell.id ? keypad?.previewText : cell.value).flatMap {
                $0.isEmpty ? nil : $0
              } ?? "—"
            )
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
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
        }
        .buttonStyle(.plain)
        .frame(maxWidth: cell.field == .weight ? .infinity : 62)
      }
    }
  }
  private func switchEffort(_ field: MeetPRNumberPad.Field) {
    guard let viewModel else { return }
    keypad?.openAllDay(draft: draft, viewModel: viewModel, field: field)
  }

}

private struct AllDayOriginalValue: View {
  let value: String
  var body: some View {
    Text(StudentStrings.replacing(.allDayOriginal, values: [value]))
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      .foregroundStyle(Color.MeetPR.textSecondary)
  }
}
