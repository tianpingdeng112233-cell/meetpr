import CoreModels
import DesignSystem
import SwiftUI

/// Per-set intensity review (spec 043 §E5): the coach fills the values the
/// parser left blank (reps / weight / RPE) and may edit the carried cue. A set
/// that fails the completeness gate (§H) is flagged 「待你定」.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct IntensityReviewSection: View {
  @Binding var set: ImportReviewSet

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(CoachImportStrings.setNumber(set.setNumber))
          .font(.footnote.monospacedDigit().bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        if !ImportCompleteness.isComplete(set) {
          Text(CoachImportStrings.needsYourInput)
            .font(.caption2.bold())
            .foregroundStyle(Color.MeetPR.amber)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.MeetPR.amberSoft)
            .clipShape(.capsule)
        }
        Spacer()
      }

      HStack(spacing: 8) {
        labeledField(CoachPlanningStrings.reps, text: intText($set.targetReps))
        labeledField(CoachImportStrings.weightKilograms, text: decimalText($set.weightKg))
        labeledField("RPE", text: decimalText($set.rpe))
      }

      labeledField(
        CoachImportStrings.coachNote,
        text: optionalText($set.coachNote),
        usesDefaultKeyboard: true
      )
    }
    .padding(10)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 10))
  }

  private func labeledField(
    _ label: String,
    text: Binding<String>,
    usesDefaultKeyboard: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      TextField(label, text: text)
        .font(.footnote)
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
          .keyboardType(usesDefaultKeyboard ? .default : .numbersAndPunctuation)
        #endif
    }
  }

  // MARK: - optional <-> string proxies

  private func intText(_ binding: Binding<Int?>) -> Binding<String> {
    Binding(
      get: { binding.wrappedValue.map(String.init) ?? "" },
      set: { binding.wrappedValue = Int($0.trimmingCharacters(in: .whitespaces)) }
    )
  }

  private func decimalText(_ binding: Binding<Decimal?>) -> Binding<String> {
    Binding(
      get: { binding.wrappedValue.map { NSDecimalNumber(decimal: $0).stringValue } ?? "" },
      set: { binding.wrappedValue = Decimal(string: $0.trimmingCharacters(in: .whitespaces)) }
    )
  }

  private func optionalText(_ binding: Binding<String?>) -> Binding<String> {
    Binding(
      get: { binding.wrappedValue ?? "" },
      set: { newValue in
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        binding.wrappedValue = trimmed.isEmpty ? nil : newValue
      }
    )
  }
}
