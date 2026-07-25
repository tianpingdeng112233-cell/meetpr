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
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      HStack(spacing: MeetPRSpacing.space2) {
        Text("第 \(set.setNumber) 组")
          .font(.footnote.monospacedDigit().bold())
          .foregroundStyle(Color.MeetPR.textPrimary)
        if !ImportCompleteness.isComplete(set) {
          Text("待你定")
            .font(.caption2.bold())
            .foregroundStyle(Color.MeetPR.gold500)
            .padding(.horizontal, MeetPRSpacing.point6)
            .padding(.vertical, MeetPRSpacing.point2)
            .background(Color.MeetPR.goldSoft)
            .clipShape(.capsule)
        }
        Spacer()
      }

      HStack(spacing: MeetPRSpacing.space2) {
        labeledField("次数", text: intText($set.targetReps))
        labeledField("重量kg", text: decimalText($set.weightKg))
        labeledField("RPE", text: decimalText($set.rpe))
      }

      labeledField("教练备注", text: optionalText($set.coachNote))
    }
    .padding(MeetPRSpacing.point10)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.chip))
  }

  private func labeledField(_ label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(Color.MeetPR.textSecondary)
      TextField(label, text: text)
        .font(.footnote)
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
          .keyboardType(label == "教练备注" ? .default : .numbersAndPunctuation)
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
