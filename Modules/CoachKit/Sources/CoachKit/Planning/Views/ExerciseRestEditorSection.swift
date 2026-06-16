import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct ExerciseRestEditorSection: View {
  let setCount: Int
  let intensityMode: IntensityMode
  let targetValue: Decimal
  @Binding var restSeconds: Int?
  @Binding var restSecondsPerSet: [Int]?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      RestSecondsPicker(label: "组间休息", value: singleRestBinding)

      Toggle("逐组单独设", isOn: perSetEnabledBinding)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      if restSecondsPerSet != nil {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          ForEach(0..<max(1, setCount), id: \.self) { index in
            HStack(spacing: MeetPRSpacing.sm) {
              Text("第\(index + 1)组")
                .font(Font.MeetPR.footnote)
                .foregroundStyle(Color.MeetPR.fgSecondary)
                .frame(width: 48, alignment: .leading)

              RestSecondsPicker(label: "休息", value: perSetBinding(at: index))
            }
          }
        }
        .padding(.top, MeetPRSpacing.xs)
      }
    }
  }

  private var singleRestBinding: Binding<Int> {
    Binding(
      get: { singleRestSeconds },
      set: { restSeconds = $0 }
    )
  }

  private var perSetEnabledBinding: Binding<Bool> {
    Binding(
      get: { restSecondsPerSet != nil },
      set: { isEnabled in
        restSecondsPerSet =
          isEnabled
          ? Array(repeating: singleRestSeconds, count: max(1, setCount))
          : nil
      }
    )
  }

  private func perSetBinding(at index: Int) -> Binding<Int> {
    Binding(
      get: {
        let values = normalizedPerSetValues()
        guard values.indices.contains(index) else { return singleRestSeconds }
        return values[index]
      },
      set: { newValue in
        var values = normalizedPerSetValues()
        guard values.indices.contains(index) else { return }
        values[index] = newValue
        restSecondsPerSet = values
      }
    )
  }

  private func normalizedPerSetValues() -> [Int] {
    var values = restSecondsPerSet ?? []
    let desiredCount = max(1, setCount)
    if values.count > desiredCount {
      values.removeLast(values.count - desiredCount)
    } else if values.count < desiredCount {
      values.append(
        contentsOf: repeatElement(singleRestSeconds, count: desiredCount - values.count)
      )
    }
    return values
  }

  private var singleRestSeconds: Int {
    restSeconds ?? RestDefaults.seconds(forRPE: intensityMode == .rpe ? targetValue : nil)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct RestSecondsPicker: View {
  let label: String
  @Binding var value: Int

  var body: some View {
    PlanningCountPicker(
      label: label,
      value: secondsBinding,
      range: 30...600,
      step: 15,
      displayText: { seconds in
        RestDurationText.string(for: Int(seconds))
      }
    )
  }

  private var secondsBinding: Binding<Double> {
    Binding(
      get: { Double(value) },
      set: { value = Int($0) }
    )
  }
}

private enum RestDurationText {
  static func string(for seconds: Int) -> String {
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    let paddedSeconds =
      remainingSeconds < 10
      ? "0\(remainingSeconds)"
      : "\(remainingSeconds)"
    return "\(minutes):\(paddedSeconds)"
  }
}
