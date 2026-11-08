import DesignSystem
import SwiftUI

struct AccessoryLogRow: View {
  @Binding var row: AccessoryRow
  let number: Int
  var columnEffortMode: ActualEffortMode = .rpe
  let isSaving: Bool
  let isDisabled: Bool
  let showsValidation: Bool
  let onEdit: () -> Void
  let onSave: () -> Void
  var activeField: MeetPRNumberPad.Field?
  var onInput: (MeetPRNumberPad.Field) -> Void = { _ in }
  @State private var editedWeight = false

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      if row.input.effortMode != columnEffortMode {
        Text(
          row.draft.hasSavedRecord
            ? StudentStrings.replacing(
              .accessoryRecordedEffort, values: [String(number), row.input.effortMode.label])
            : row.input.effortMode.label
        )
        .font(.caption2).foregroundStyle(Color.MeetPR.textSecondary)
      }
      AccessoryColumns {
        Button(action: onEdit) {
          VStack(spacing: MeetPRSpacing.zero) {
            Text(row.draft.isExtra ? StudentStrings.localized(.addedExtra) : String(number)).font(
              .MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .bold))
            if row.hasVideo {
              Image(
                systemName: row.hasVideoFailure ? "exclamationmark.triangle.fill" : "video.fill"
              )
              .font(.caption2)
              .foregroundStyle(row.hasVideoFailure ? Color.MeetPR.danger : Color.MeetPR.success)
            }
          }
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
          .background(Color.MeetPR.surfaceRaised, in: .rect(cornerRadius: MeetPRRadius.inset))
        }
        .disabled(row.draft.isStudentAdded)
        .accessibilityLabel(copy(.accessoryDetails))
        .accessibilityIdentifier("accessory.set.\(number).details")
        Button {
          row.usePrevious()
        } label: {
          Text(row.previousText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
            .lineLimit(1)
            .minimumScaleFactor(MeetPRFontMetrics.size10 / MeetPRFontMetrics.size11)
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        }
        .foregroundStyle(Color.MeetPR.textMuted)
        .disabled(row.previousReps == nil)
        .accessibilityLabel(copy(.accessoryUseLast))
        field(
          .weight, text: $row.input.weight,
          placeholder: row.isBodyweight ? "0" : row.weightPlaceholder,
          invalid: row.weightKg == nil
            && (!row.input.weight.isEmpty || editedWeight || showsValidation))
        field(.reps, text: $row.input.reps, placeholder: "", invalid: row.reps == nil)
        field(
          .rpe, text: $row.input.rpe, placeholder: row.isRecorded ? "" : row.rpePlaceholder,
          invalid: !row.isRPEValid)
        Button(action: onSave) {
          Group {
            if isSaving { ProgressView() } else { Image(systemName: "checkmark").bold() }
          }
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
          .foregroundStyle(row.draft.completed ? Color.MeetPR.bgBase : Color.MeetPR.textPrimary)
          .background(
            row.draft.completed ? Color.MeetPR.success : Color.MeetPR.surfaceCard,
            in: .circle
          )
          .overlay(
            Circle().strokeBorder(
              row.isWritable || row.isCancellation
                ? Color.MeetPR.textPrimary : Color.MeetPR.textGhost,
              lineWidth: row.draft.completed ? 0 : 2)
          )
          .opacity(row.isWritable || row.isCancellation ? 1 : 0.4)
        }
        .disabled(!row.isWritable && !row.isCancellation)
        .accessibilityLabel(copy(row.isCancellation ? .accessoryUndo : .accessoryComplete))
        .accessibilityIdentifier("accessory.set.\(number).save")
      }
      .padding(.vertical, MeetPRSpacing.space1)
      .background(
        activeField != nil
          ? Color.MeetPR.goldRGB.opacity(0.08)
          : row.draft.completed ? Color.MeetPR.success.opacity(0.1) : .clear,
        in: .rect(cornerRadius: MeetPRRadius.inset)
      )
      .buttonStyle(.plain)
      .disabled(isDisabled)
      if let note = row.extraNote {
        Text(note)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.coachNoteText)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func field(
    _ field: MeetPRNumberPad.Field, text: Binding<String>, placeholder: String, invalid: Bool
  ) -> some View {
    let resolvedField: MeetPRNumberPad.Field =
      field == .rpe && columnEffortMode == .rir ? .rir : field
    let active = activeField == resolvedField
    return Button {
      onInput(resolvedField)
    } label: {
      Text(
        text.wrappedValue.isEmpty ? (placeholder.isEmpty ? "—" : placeholder) : text.wrappedValue
      )
      .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .semibold))
    .multilineTextAlignment(.center)
    .minimumScaleFactor(0.5)
    .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    .background(
      row.draft.completed ? .clear : Color.MeetPR.surfaceCard,
      in: .rect(cornerRadius: MeetPRRadius.inset)
    )
    .overlay(
      RoundedRectangle(cornerRadius: MeetPRRadius.inset).strokeBorder(
        active ? Color.MeetPR.gold500 : invalid ? Color.MeetPR.danger : Color.MeetPR.borderStrong,
        lineWidth: active ? 2 : row.draft.completed && !invalid ? 0 : 1)
    )
    .accessibilityLabel(
      copy(
        field == .weight
          ? .accessoryWeightLabel
          : field == .reps
            ? .accessoryRepsLabel
            : row.input.effortMode == .rir ? .accessoryRirLabel : .accessoryRpeLabel)
    )
    .accessibilityValue(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)
    .accessibilityIdentifier("accessory.set.\(number).\(field)")
    .onChange(of: row.input.weight) { _, _ in editedWeight = true }

  }

  private func copy(_ key: StudentStrings.Key) -> String {
    StudentStrings.replacing(key, values: [String(number)])
  }
}
