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
  @State private var expandedField: ExpandedField?

  private enum ExpandedField: Hashable {
    case setCount
    case targetReps
    case targetRepsMax
    case rpe
  }

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
          PlanningCountPicker(
            label: "RPE",
            value: rpeBinding,
            range: 1...10,
            step: 0.5,
            isExpanded: isExpandedBinding(for: .rpe)
          )
        }

        PlanningCountPicker(
          label: "组数",
          value: setCountBinding,
          range: 1...20,
          step: 1,
          isExpanded: isExpandedBinding(for: .setCount)
        )
        .onChange(of: setCount) { _, _ in persist() }

        PlanningCountPicker(
          label: "次数",
          value: targetRepsBinding,
          range: 1...50,
          step: 1,
          isExpanded: isExpandedBinding(for: .targetReps)
        )
        .onChange(of: targetReps) { _, newReps in
          if let currentMax = targetRepsMax, currentMax < newReps {
            targetRepsMax = newReps
          }
          persist()
        }

        OptionalRepsMaxRow(
          value: $targetRepsMax,
          minimum: targetReps,
          isExpanded: isExpandedBinding(for: .targetRepsMax)
        )
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

  private var setCountBinding: Binding<Double> {
    Binding(
      get: { Double(setCount) },
      set: { setCount = Int($0) }
    )
  }

  private var targetRepsBinding: Binding<Double> {
    Binding(
      get: { Double(targetReps) },
      set: { targetReps = Int($0) }
    )
  }

  private func isExpandedBinding(for field: ExpandedField) -> Binding<Bool> {
    Binding(
      get: { expandedField == field },
      set: { expandedField = $0 ? field : nil }
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
@available(iOS 17.0, macOS 14.0, *)
private struct OptionalRepsMaxRow: View {
  @Binding var value: Int?
  let minimum: Int
  @Binding var isExpanded: Bool

  var body: some View {
    if value == nil {
      Button("添加次数上限", systemImage: "plus") {
        value = minimum
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded = true
        }
      }
      .font(Font.MeetPR.footnote)
      .buttonStyle(.borderless)
    } else {
      HStack(spacing: MeetPRSpacing.sm) {
        PlanningCountPicker(
          label: "次数上限",
          value: repsMaxBinding,
          range: Double(minimum)...60,
          step: 1,
          isExpanded: $isExpanded
        )

        Button(role: .destructive) {
          value = nil
          isExpanded = false
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
