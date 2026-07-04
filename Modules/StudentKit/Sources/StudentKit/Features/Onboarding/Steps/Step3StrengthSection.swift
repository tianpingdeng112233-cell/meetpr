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
      Text("⚠️ 1RM 一旦填写,完成后只有教练能改")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      oneRMField(
        lift: .squat, title: "深蹲 1RM", text: $squatText,
        isHighlighted: highlighted.contains("squat_1rm_kg")
      ) { draft.squat1RMKg = UnitDisplay.parseOneRM($0) }
      oneRMField(
        lift: .bench, title: "卧推 1RM", text: $benchText,
        isHighlighted: highlighted.contains("bench_1rm_kg")
      ) { draft.bench1RMKg = UnitDisplay.parseOneRM($0) }
      oneRMField(
        lift: .deadlift, title: "硬拉 1RM", text: $deadliftText,
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
          .font(Font.MeetPR.title2)
          .frame(width: 44, height: 44)
          .background(Color.MeetPR.surface1)
          .overlay {
            RoundedRectangle(cornerRadius: MeetPRRadius.md)
              .stroke(Color.MeetPR.border, lineWidth: 1)
          }
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(title) 估算器")
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
      Text("用近期训练估算 1RM")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      OnboardingNumberField(
        title: "重量", unitSuffix: "kg", text: $weightText, onCommit: { _ in },
        placeholder: "100")
      OnboardingNumberField(
        title: "次数", unitSuffix: "次", text: $repsText, onCommit: { _ in }, placeholder: "5")

      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        OnboardingFieldLabel(title: "RPE: \(String(format: "%.1f", rpe))")
        Slider(value: $rpe, in: 6...10, step: 0.5)
          .tint(Color.MeetPR.brandRed)
        Text("RPE = 这组做完有多吃力:10=力竭、9=还能多做 1 次、8=还能多做 2 次。")
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }

      if let estimate {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text("估算 1RM ≈ \(UnitDisplay.plainString(estimate.estimated)) kg")
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          PrimaryButton("填入估算值", isFullWidth: true) {
            onFill(estimate.estimated)
            dismiss()
          }
          SecondaryButton(
            "保守填入 90% (\(UnitDisplay.plainString(estimate.conservative)) kg)",
            isFullWidth: true
          ) {
            onFill(estimate.conservative)
            dismiss()
          }
        }
      } else {
        Text("输入重量与次数后显示估算结果")
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      Spacer()
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.bg)
  }
}
