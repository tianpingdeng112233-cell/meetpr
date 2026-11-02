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
  @FocusState private var isFocused: Bool

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
          StudentStrings.localized(
            row.isBodyweight ? .loadTypeOptionalWeight : .loadTypeRequiredWeight)
        )
        .font(.caption2)
        .foregroundStyle(invalidWeight ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        TextField(
          StudentStrings.localized(
            row.isBodyweight ? .loadTypeOptionalPlaceholder : .loadTypeRequiredPlaceholder),
          text: $row.input.weight
        )
        .focused($isFocused)
        .modifier(LoadTypeInputStyle(invalid: invalidWeight))
        .accessibilityIdentifier("accessory.set.\(number).weight")
        #if os(iOS)
          .keyboardType(.decimalPad)
        #endif
      }
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(StudentStrings.localized(.setEntrySheet003)).font(.caption2)
          .foregroundStyle(Color.MeetPR.textSecondary)
        TextField("", text: $row.input.reps)
          .focused($isFocused)
          .modifier(LoadTypeInputStyle(invalid: showsValidation && row.reps == nil))
          .accessibilityLabel(StudentStrings.localized(.setEntrySheet003))
          .accessibilityIdentifier("accessory.set.\(number).reps")
          #if os(iOS)
            .keyboardType(.numberPad)
          #endif
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
    #if os(iOS)
      .toolbar {
        if isFocused {
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(StudentStrings.localized(.loadTypeComplete)) { isFocused = false }
          }
        }
      }
    #endif
  }
}

private struct LoadTypeInputStyle: ViewModifier {
  let invalid: Bool

  func body(content: Content) -> some View {
    content
      .textFieldStyle(.plain)
      .font(.body.monospacedDigit())
      .padding(.horizontal, MeetPRSpacing.space2)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.inset))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.inset)
          .strokeBorder(invalid ? Color.MeetPR.danger : Color.MeetPR.borderStrong)
      }
  }
}
