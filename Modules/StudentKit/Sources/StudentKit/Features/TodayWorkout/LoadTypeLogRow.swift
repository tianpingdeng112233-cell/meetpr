import CoreModels
import DesignSystem
import SwiftUI

/// The approved free-weight/bodyweight row keeps the weight label visible while editing.
struct LoadTypeLogRow: View {
  @Binding var row: AccessoryRow
  let number: Int
  let isSaving: Bool
  let isDisabled: Bool
  let showsValidation: Bool
  let onEdit: () -> Void
  let onSave: () -> Void
  var activeField: MeetPRNumberPad.Field?
  var onInput: (MeetPRNumberPad.Field) -> Void = { _ in }

  private var invalidWeight: Bool {
    showsValidation && row.weightKg == nil
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: MeetPRSpacing.space2) {
      Button(action: onEdit) {
        Text(StudentStrings.replacing(.loadTypeSet, values: [String(number)]))
          .font(.caption)
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("accessory.set.\(number).details")
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(
          StudentStrings.replacing(
            row.isBodyweight ? .keypadOptionalWeight : .keypadRequiredWeight,
            values: [UnitDisplay.weightUnitSuffix(row.unit).uppercased()])
        )
        .font(.caption2)
        .foregroundStyle(invalidWeight ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        Button {
          onInput(.weight)
        } label: {
          Text(
            row.input.weight.isEmpty
              ? StudentStrings.localized(
                row.isBodyweight ? .loadTypeOptionalPlaceholder : .loadTypeRequiredPlaceholder)
              : row.input.weight
          )
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        }
        .modifier(LoadTypeInputStyle(invalid: invalidWeight, active: activeField == .weight))
        .accessibilityLabel(
          StudentStrings.replacing(.accessoryWeightLabel, values: [String(number)])
        )
        .accessibilityValue(row.input.weight)
        .accessibilityIdentifier("accessory.set.\(number).weight")
      }
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(StudentStrings.localized(.setEntrySheet003)).font(.caption2)
          .foregroundStyle(Color.MeetPR.textSecondary)
        Button {
          onInput(.reps)
        } label: {
          Text(row.input.reps.isEmpty ? "—" : row.input.reps)
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        }
        .modifier(
          LoadTypeInputStyle(
            invalid: showsValidation && row.reps == nil, active: activeField == .reps)
        )
        .accessibilityLabel(StudentStrings.localized(.setEntrySheet003))
        .accessibilityValue(row.input.reps)
        .accessibilityIdentifier("accessory.set.\(number).reps")
      }
      .frame(maxWidth: MeetPRSpacing.minimumHitTarget)
      Button(action: onSave) {
        Group {
          if isSaving {
            ProgressView()
          } else {
            Text(StudentStrings.localized(row.isCancellation ? .loadTypeUndo : .loadTypeComplete))
          }
        }
        .font(.caption.bold())
        .frame(minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
        .foregroundStyle(row.isRecorded ? Color.MeetPR.success : Color.MeetPR.textPrimary)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("accessory.set.\(number).save")
    }
    .disabled(isDisabled)
    .buttonStyle(.plain)
    .background(
      activeField != nil ? Color.MeetPR.goldRGB.opacity(0.08) : .clear,
      in: .rect(cornerRadius: MeetPRRadius.inset))
  }
}

private struct LoadTypeInputStyle: ViewModifier {
  let invalid: Bool
  var active = false

  func body(content: Content) -> some View {
    content
      .foregroundStyle(Color.MeetPR.textPrimary)
      .font(.body.monospacedDigit())
      .padding(.horizontal, MeetPRSpacing.space2)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.inset))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.inset)
          .strokeBorder(
            active
              ? Color.MeetPR.gold500
              : invalid
                ? Color.MeetPR.danger
                : Color.MeetPR.borderStrong, lineWidth: active ? 2 : 1)
      }
  }
}
