import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct ExerciseSetEditorCard: View {
  @Bindable private var viewModel: PlanningViewModel
  private let draftExercise: DraftPlanExercise

  @State private var specID: UUID
  @State private var setCount: Int
  @State private var targetReps: Int
  @State private var targetRepsMax: Int?
  @State private var intensityMode: IntensityMode
  @State private var targetValue: Decimal
  @State private var didSave = false

  public init(viewModel: PlanningViewModel, draftExercise: DraftPlanExercise) {
    self.viewModel = viewModel
    self.draftExercise = draftExercise
    let spec =
      viewModel.setSpec(for: draftExercise.id) ?? viewModel.defaultSetSpec(for: draftExercise)
    self._specID = State(initialValue: spec.id)
    self._setCount = State(initialValue: spec.setCount)
    self._targetReps = State(initialValue: spec.targetReps)
    self._targetRepsMax = State(initialValue: spec.targetRepsMax)
    self._intensityMode = State(initialValue: spec.intensityMode)
    self._targetValue = State(initialValue: spec.targetValue)
    self._didSave = State(initialValue: viewModel.setSpec(for: draftExercise.id) != nil)
  }

  public var body: some View {
    Card(accessibilityLabel: "Exercise set editor") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        header

        IntensityModeToggle(mode: $intensityMode)
          .onChange(of: intensityMode) { _, newValue in
            Task {
              await viewModel.toggleIntensityMode(to: newValue, for: draftExercise.id)
              syncFromViewModel()
            }
          }

        if intensityMode == .weight {
          WeightInputField(
            value: targetValue,
            oneRM: viewModel.oneRM(for: draftExercise),
            onChange: { value in
              targetValue = value
              persist()
            }
          )
        } else {
          RPEInput(value: rpeBinding)
        }

        HStack(spacing: MeetPRSpacing.md) {
          CountStepper(title: "组数", value: $setCount, range: 1...20)
          CountStepper(title: "次数", value: $targetReps, range: 1...50)
        }
        .onChange(of: setCount) { _, _ in persist() }
        .onChange(of: targetReps) { _, _ in persist() }

        OptionalRepsMaxStepper(value: $targetRepsMax, minimum: targetReps)
          .onChange(of: targetRepsMax) { _, _ in persist() }

        PrimaryButton(didSave ? "更新 W1 设置" : "保存 W1 设置", isFullWidth: true) {
          persist()
        }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
      Text(viewModel.exerciseName(for: draftExercise))
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      if draftExercise.isMainLift {
        StatusBadge(status: .live, title: "主项")
      }

      Spacer()

      if didSave {
        StatusBadge(status: .ready, title: "已填")
      }
    }
  }

  private var rpeBinding: Binding<Double> {
    Binding(
      get: { NSDecimalNumber(decimal: targetValue).doubleValue },
      set: { newValue in
        targetValue = Decimal(newValue)
        persist()
      }
    )
  }

  private func currentSpec() -> DraftSetSpec {
    DraftSetSpec(
      id: specID,
      setCount: setCount,
      targetReps: targetReps,
      targetRepsMax: targetRepsMax,
      intensityMode: intensityMode,
      targetValue: targetValue
    )
  }

  private func persist() {
    Task {
      try? await viewModel.updateW1SetSpec(currentSpec(), for: draftExercise.id)
      didSave = viewModel.setSpec(for: draftExercise.id) != nil
    }
  }

  private func syncFromViewModel() {
    guard let spec = viewModel.setSpec(for: draftExercise.id) else { return }
    specID = spec.id
    setCount = spec.setCount
    targetReps = spec.targetReps
    targetRepsMax = spec.targetRepsMax
    intensityMode = spec.intensityMode
    targetValue = spec.targetValue
    didSave = true
  }
}

@MainActor
private struct RPEInput: View {
  @Binding var value: Double

  var body: some View {
    Stepper(value: $value, in: 1...10, step: 0.5) {
      HStack {
        Text("RPE")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Spacer()
        Text(value.formatted(.number.precision(.fractionLength(1))))
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .monospacedDigit()
      }
    }
  }
}

@MainActor
private struct CountStepper: View {
  let title: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    Stepper(value: $value, in: range) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(title)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Text(value.formatted())
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .monospacedDigit()
      }
    }
  }
}

@MainActor
private struct OptionalRepsMaxStepper: View {
  @Binding var value: Int?
  let minimum: Int

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Toggle("次数上限", isOn: hasRangeBinding)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      if value != nil {
        Stepper(value: repsMaxBinding, in: minimum...60) {
          Text("最多 \(value ?? minimum) 次")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }
      }
    }
  }

  private var hasRangeBinding: Binding<Bool> {
    Binding(
      get: { value != nil },
      set: { isOn in value = isOn ? max(minimum, value ?? minimum) : nil }
    )
  }

  private var repsMaxBinding: Binding<Int> {
    Binding(
      get: { value ?? minimum },
      set: { value = max(minimum, $0) }
    )
  }
}
