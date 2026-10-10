import DesignSystem
import SwiftUI

struct AccessoryLogRow: View {
  @Binding var row: AccessoryRow
  let number: Int
  let isSaving: Bool
  let isDisabled: Bool
  let showsValidation: Bool
  let onEdit: () -> Void
  let onSave: () -> Void
  @FocusState private var focusedField: Field?
  @State private var editedWeight = false

  private enum Field: Hashable { case weight, reps, rpe }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      AccessoryColumns {
        Button(action: onEdit) {
          VStack(spacing: MeetPRSpacing.zero) {
            Text(String(number)).font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .bold))
            if row.hasVideo {
              Image(systemName: "video.fill")
                .font(.caption2)
                .foregroundStyle(Color.MeetPR.goldText)
            }
          }
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
          .background(Color.MeetPR.surfaceRaised, in: .rect(cornerRadius: MeetPRRadius.inset))
        }
        .accessibilityLabel(copy(.accessoryDetails))
        .accessibilityIdentifier("accessory.set.\(number).details")
        Button {
          row.usePrevious()
        } label: {
          Text(
            row.previous.map {
              [
                row.isBodyweight ? StudentStrings.localized(.accessoryBw) : row.weightPlaceholder,
                String($0.reps),
              ].joined(separator: " × ")
            } ?? "—"
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        }
        .foregroundStyle(Color.MeetPR.textMuted)
        .disabled(row.previous == nil)
        .accessibilityLabel(copy(.accessoryUseLast))
        if row.isBodyweight {
          Text(StudentStrings.localized(.accessoryBw))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
        } else {
          field(
            .weight, text: $row.input.weight, placeholder: row.weightPlaceholder,
            invalid: row.weightKg == nil
              && (!row.input.weight.isEmpty || editedWeight || showsValidation))
        }
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
        row.draft.completed ? Color.MeetPR.success.opacity(0.1) : .clear,
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
    #if os(iOS)
      .toolbar {
        if focusedField != nil {
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(StudentStrings.localized(.workoutCompletionFlowView003)) { focusedField = nil }
          }
        }
      }
    #endif
  }

  private func field(
    _ field: Field, text: Binding<String>, placeholder: String, invalid: Bool
  ) -> some View {
    TextField(placeholder, text: text)
      .textFieldStyle(.plain)
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .semibold))
      .multilineTextAlignment(.center)
      .minimumScaleFactor(0.5)
      .focused($focusedField, equals: field)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .background(
        row.draft.completed ? .clear : Color.MeetPR.surfaceCard,
        in: .rect(cornerRadius: MeetPRRadius.inset)
      )
      .overlay(
        RoundedRectangle(cornerRadius: MeetPRRadius.inset).strokeBorder(
          invalid ? Color.MeetPR.danger : Color.MeetPR.borderStrong,
          lineWidth: row.draft.completed && !invalid && focusedField != field ? 0 : 1)
      )
      .accessibilityLabel(
        copy(
          field == .weight
            ? .accessoryWeightLabel : field == .reps ? .accessoryRepsLabel : .accessoryRpeLabel)
      )
      .accessibilityIdentifier("accessory.set.\(number).\(field)")
      .onChange(of: row.input.weight) { _, _ in editedWeight = true }
      #if os(iOS)
        .keyboardType(field == .reps ? .numberPad : .decimalPad)
      #endif
  }

  private func copy(_ key: StudentStrings.Key) -> String {
    StudentStrings.replacing(key, values: [String(number)])
  }
}
