import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PerSetTargetRow: View {
  let index: Int
  @Binding var target: DraftSetTarget
  let intensityMode: IntensityMode
  let bases: [WeightEntryBase]

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text("第\(index + 1)组")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      HStack(alignment: .bottom, spacing: MeetPRSpacing.sm) {
        if intensityMode == .weight {
          PerSetWeightButton(
            setNumber: index + 1,
            value: target.targetValue,
            bases: bases,
            onChange: { value in
              target.intensityMode = .weight
              target.targetValue = value
            }
          )
        } else {
          PlanningCountPicker(
            label: "RPE",
            value: rpeBinding,
            range: 1...10,
            step: 0.5
          )
        }

        PlanningCountPicker(
          label: "次数",
          value: repsBinding,
          range: 1...50,
          step: 1
        )
      }
    }
    .padding(MeetPRSpacing.sm)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }

  private var rpeBinding: Binding<Double> {
    Binding(
      get: { target.targetValue.planningDoubleValue },
      set: { value in
        target.intensityMode = .rpe
        target.targetValue = Decimal.planningRounded(value, increment: PlanningDecimalStep.half)
      }
    )
  }

  private var repsBinding: Binding<Double> {
    Binding(
      get: { Double(target.targetReps) },
      set: { value in
        target.targetReps = max(1, Int(value))
        if let targetRepsMax = target.targetRepsMax, targetRepsMax < target.targetReps {
          target.targetRepsMax = target.targetReps
        }
      }
    )
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PerSetWeightButton: View {
  let setNumber: Int
  let value: Decimal
  let bases: [WeightEntryBase]
  let onChange: @MainActor (Decimal) -> Void
  @State private var showPanel = false

  var body: some View {
    VStack(spacing: MeetPRSpacing.xs) {
      Text("重量")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      Button {
        showPanel = true
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.xs) {
          Text(value.planningFormatted())
            .font(Font.MeetPR.body)
            .monospacedDigit()
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("kg")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .padding(.horizontal, MeetPRSpacing.sm)
        .padding(.vertical, MeetPRSpacing.xs)
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("编辑第\(setNumber)组重量")
    }
    .frame(maxWidth: .infinity)
    .sheet(isPresented: $showPanel) {
      WeightEntryPanel(
        title: "目标重量",
        initialValue: value,
        bases: bases
      ) { kilograms in
        onChange(kilograms)
      }
      .presentationDetents([.fraction(0.75), .large])
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct OptionalRepsMaxRow: View {
  @Binding var value: Int?
  let minimum: Int

  var body: some View {
    if value == nil {
      Button("添加次数上限", systemImage: "plus") {
        value = minimum
      }
      .font(Font.MeetPR.footnote)
      .buttonStyle(.borderless)
    } else {
      HStack(spacing: MeetPRSpacing.sm) {
        PlanningCountPicker(
          label: "次数上限",
          value: repsMaxBinding,
          range: Double(minimum)...60,
          step: 1
        )

        Button(role: .destructive) {
          value = nil
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.body)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("删除次数上限")
      }
    }
  }

  private var repsMaxBinding: Binding<Double> {
    Binding(
      get: { Double(value ?? minimum) },
      set: { value = max(minimum, Int($0)) }
    )
  }
}
