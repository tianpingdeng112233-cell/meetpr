import CoreModels
import DesignSystem
import SwiftUI

/// Step 3 你的三大项极限是多少?: the three 1RMs + estimator sheet (spec 032
/// D7 — reuses the spec-028 E1RMCalculator). 1RM entry is always kg.
@available(iOS 17.0, macOS 14.0, *)
struct Step3StrengthSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []
  @State private var squatText = ""
  @State private var benchText = ""
  @State private var deadliftText = ""
  @State private var estimatorTarget: OneRMLift?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      Text(StudentStrings.localized(.step3StrengthSection001))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textSecondary)

      oneRMField(
        lift: .squat, title: StudentStrings.localized(.step3StrengthSection002), text: $squatText,
        isHighlighted: highlighted.contains("squat_1rm_kg")
      ) { draft.squat1RMKg = UnitDisplay.parseOneRM($0) }
      oneRMField(
        lift: .bench, title: StudentStrings.localized(.step3StrengthSection003), text: $benchText,
        isHighlighted: highlighted.contains("bench_1rm_kg")
      ) { draft.bench1RMKg = UnitDisplay.parseOneRM($0) }
      oneRMField(
        lift: .deadlift, title: StudentStrings.localized(.step3StrengthSection004),
        text: $deadliftText,
        isHighlighted: highlighted.contains("deadlift_1rm_kg")
      ) { draft.deadlift1RMKg = UnitDisplay.parseOneRM($0) }
    }
    .onAppear {
      squatText = UnitDisplay.plainText(draft.squat1RMKg)
      benchText = UnitDisplay.plainText(draft.bench1RMKg)
      deadliftText = UnitDisplay.plainText(draft.deadlift1RMKg)
    }
    .sheet(item: $estimatorTarget) { target in
      OneRMEstimatorSheet { value in
        fill(target, with: value)
      }
      #if os(iOS)
        .presentationDetents([.medium, .large])
      #endif
    }
  }

  private func oneRMField(
    lift: OneRMLift,
    title: String,
    text: Binding<String>,
    isHighlighted: Bool,
    onCommit: @escaping (String) -> Void
  ) -> some View {
    HStack(alignment: .bottom, spacing: MeetPRSpacing.sm) {
      OnboardingNumberField(
        title: title,
        unitSuffix: "kg",
        text: text,
        onCommit: onCommit,
        isHighlighted: isHighlighted,
        placeholder: "0"
      )
      Button {
        estimatorTarget = lift
      } label: {
        Text("🧮")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size28))
          .frame(width: 44, height: 44)
          .background(Color.MeetPR.surfaceCard)
          .overlay {
            RoundedRectangle(cornerRadius: MeetPRRadius.md)
              .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
          }
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
      .accessibilityLabel(StudentStrings.replacing(.step3StrengthSection005, values: ["\(title)"]))
    }
  }

  private func fill(_ lift: OneRMLift, with value: Decimal) {
    let text = UnitDisplay.plainString(value)
    switch lift {
    case .squat:
      draft.squat1RMKg = value
      squatText = text
    case .bench:
      draft.bench1RMKg = value
      benchText = text
    case .deadlift:
      draft.deadlift1RMKg = value
      deadliftText = text
    }
  }
}

private enum OneRMLift: String, Identifiable {
  case squat, bench, deadlift

  var id: String { rawValue }
}

extension UnitDisplay {
  fileprivate static func plainText(_ value: Decimal?) -> String {
    value.map(plainString) ?? ""
  }
}

/// "不确定?用近期训练估算" sheet: weight × reps @ RPE → estimated / 90%.
@available(iOS 17.0, macOS 14.0, *)
struct OneRMEstimatorSheet: View {
  let onFill: (Decimal) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var weightText = ""
  @State private var repsText = ""
  @State private var rpe: Double = 8

  private var estimate: OneRMEstimator.Estimate? {
    guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
      let reps = Int(repsText)
    else { return nil }
    return OneRMEstimator.estimate(weightKg: weight, reps: reps, rpe: rpe)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      Text(StudentStrings.localized(.step3StrengthSection006))
        .font(.MeetPR.display(size: MeetPRFontMetrics.size28))
        .foregroundStyle(Color.MeetPR.textPrimary)

      OnboardingNumberField(
        title: StudentStrings.localized(.step3StrengthSection007), unitSuffix: "kg",
        text: $weightText, onCommit: { _ in },
        placeholder: "100")
      OnboardingNumberField(
        title: StudentStrings.localized(.step3StrengthSection008),
        unitSuffix: StudentStrings.localized(.step3StrengthSection009), text: $repsText,
        onCommit: { _ in }, placeholder: "5")

      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        OnboardingFieldLabel(title: "RPE: \(String(format: "%.1f", rpe))")
        Slider(value: $rpe, in: 6...10, step: 0.5)
          .tint(Color.MeetPR.gold500)
        Text(StudentStrings.localized(.step3StrengthSection010))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }

      if let estimate {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text(
            StudentStrings.replacing(
              .step3StrengthSection011, values: ["\(UnitDisplay.plainString(estimate.estimated))"])
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          GoldCTA(StudentStrings.localized(.step3StrengthSection012), sub: nil, icon: .none) {
            onFill(estimate.estimated)
            dismiss()
          }
          SecondaryButton(
            StudentStrings.replacing(
              .step3StrengthSection013,
              values: ["\(UnitDisplay.plainString(estimate.conservative))"]),
            isFullWidth: true
          ) {
            onFill(estimate.conservative)
            dismiss()
          }
        }
      } else {
        Text(StudentStrings.localized(.step3StrengthSection014))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      Spacer()
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.bgBase)
  }
}
