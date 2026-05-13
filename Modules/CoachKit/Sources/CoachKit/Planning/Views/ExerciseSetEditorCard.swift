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
          LabeledIntegerPlanningNumberField(title: "组数", value: $setCount, range: 1...20)
          LabeledIntegerPlanningNumberField(title: "次数", value: $targetReps, range: 1...50)
        }
        .onChange(of: setCount) { _, _ in persist() }
        .onChange(of: targetReps) { _, newReps in
          if let currentMax = targetRepsMax, currentMax < newReps {
            targetRepsMax = newReps
          }
          persist()
        }

        OptionalRepsMaxInput(value: $targetRepsMax, minimum: targetReps)
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
      get: { targetValue.planningDoubleValue },
      set: { newValue in
        targetValue = Decimal.planningRounded(newValue, increment: PlanningDecimalStep.half)
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
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text("RPE")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      PlanningNumberField(
        value: $value,
        range: 1...10,
        step: 0.5,
        decimalIncrement: PlanningDecimalStep.half
      )
    }
  }
}

@MainActor
private struct LabeledIntegerPlanningNumberField: View {
  let title: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(title)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      PlanningNumberField(
        value: doubleBinding,
        range: Double(range.lowerBound)...Double(range.upperBound),
        step: 1,
        decimalIncrement: PlanningDecimalStep.whole
      )
    }
  }

  private var doubleBinding: Binding<Double> {
    Binding(
      get: { Double(value) },
      set: { value = Int($0) }
    )
  }
}

@MainActor
private struct OptionalRepsMaxInput: View {
  @Binding var value: Int?
  let minimum: Int

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text("次数上限")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      if value == nil {
        Button("添加上限", systemImage: "plus") {
          value = minimum
        }
        .font(Font.MeetPR.footnote)
        .buttonStyle(.borderless)
      } else {
        HStack(spacing: MeetPRSpacing.sm) {
          PlanningNumberField(
            value: repsMaxBinding,
            range: Double(minimum)...60,
            step: 1,
            decimalIncrement: PlanningDecimalStep.whole
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
  }

  private var repsMaxBinding: Binding<Double> {
    Binding(
      get: { Double(value ?? minimum) },
      set: { value = max(minimum, Int($0)) }
    )
  }
}
