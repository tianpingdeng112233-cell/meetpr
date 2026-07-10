import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct ExerciseSetEditorCard: View {
  @Bindable private var viewModel: PlanningViewModel
  private let draftExercise: DraftPlanExercise
  private let onDelete: (@MainActor () -> Void)?

  @State private var specID: UUID
  @State private var setCount: Int
  @State private var targetReps: Int
  @State private var targetRepsMax: Int?
  @State private var intensityMode: IntensityMode
  @State private var targetValue: Decimal
  @State private var restSeconds: Int?
  @State private var restSecondsPerSet: [Int]?
  @State private var perSetTargets: [DraftSetTarget]?
  @State private var notes: String

  public init(
    viewModel: PlanningViewModel,
    draftExercise: DraftPlanExercise,
    onDelete: (@MainActor () -> Void)? = nil
  ) {
    self.viewModel = viewModel
    self.draftExercise = draftExercise
    self.onDelete = onDelete
    let spec =
      viewModel.setSpec(for: draftExercise.id) ?? viewModel.defaultSetSpec(for: draftExercise)
    self._specID = State(initialValue: spec.id)
    self._setCount = State(initialValue: spec.setCount)
    self._targetReps = State(initialValue: spec.targetReps)
    self._targetRepsMax = State(initialValue: spec.targetRepsMax)
    self._intensityMode = State(initialValue: spec.intensityMode)
    self._targetValue = State(initialValue: spec.targetValue)
    self._restSeconds = State(initialValue: spec.restSeconds)
    self._restSecondsPerSet = State(initialValue: spec.restSecondsPerSet)
    self._perSetTargets = State(initialValue: spec.perSetTargets)
    self._notes = State(initialValue: draftExercise.notes ?? "")
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

        if perSetTargets == nil {
          commonPrescriptionEditor
        } else {
          setCountPicker
        }

        Toggle("逐组单独设", isOn: perSetTargetsEnabledBinding)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)

        if perSetTargets != nil {
          perSetTargetsEditor
        }

        ExerciseRestEditorSection(
          setCount: setCount,
          intensityMode: intensityMode,
          targetValue: targetValue,
          restSeconds: $restSeconds,
          restSecondsPerSet: $restSecondsPerSet
        )
        .onChange(of: restSeconds) { _, _ in persist() }
        .onChange(of: restSecondsPerSet) { _, _ in persist() }

        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Text("备注")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          TextField(
            "可选 · 比如暂停 3 秒 / 节奏 3-0-1 / 卧距宽",
            text: $notes,
            axis: .vertical
          )
          .lineLimit(1...3)
          .padding(MeetPRSpacing.sm)
          .background(Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
          .onChange(of: notes) { _, newValue in
            Task {
              try? await viewModel.updateExerciseNotes(newValue, for: draftExercise.id)
            }
          }
        }
      }
    }
    .task {
      // Persist the default spec the first time the card appears so the
      // downstream W1 validation doesn't reject exercises the coach never
      // touched. Subsequent loads short-circuit because setSpec is non-nil.
      if viewModel.setSpec(for: draftExercise.id) == nil {
        persist()
      }
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.sm) {
      VStack(alignment: .leading, spacing: 2) {
        Text(viewModel.exerciseName(for: draftExercise))
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
      }

      if draftExercise.isMainLift {
        StatusBadge(status: .live, title: "主项")
      }

      Spacer()

      // 已填 reflects a real load now, not just that a default spec exists
      // (David 2026-06-14). Computed from live edit state so it flips the
      // moment the coach enters a weight / RPE.
      if currentSpec().isCoachComplete {
        StatusBadge(status: .ready, title: "已填")
      }

      if let onDelete {
        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("删除 \(viewModel.exerciseName(for: draftExercise))")
      }
    }
  }

  @ViewBuilder
  private var commonPrescriptionEditor: some View {
    intensityValueEditor

    HStack(spacing: MeetPRSpacing.md) {
      setCountPicker

      PlanningCountPicker(
        label: "次数",
        value: targetRepsBinding,
        range: 1...50,
        step: 1
      )
      .onChange(of: targetReps) { _, newReps in
        if let currentMax = targetRepsMax, currentMax < newReps {
          targetRepsMax = newReps
        }
        persist()
      }
    }

    OptionalRepsMaxRow(
      value: $targetRepsMax,
      minimum: targetReps
    )
    .onChange(of: targetRepsMax) { _, _ in persist() }
  }

  @ViewBuilder
  private var intensityValueEditor: some View {
    if intensityMode == .weight {
      WeightInputField(
        value: targetValue,
        oneRM: viewModel.oneRM(for: draftExercise),
        bases: viewModel.weightEntryBases(for: draftExercise),
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
        step: 0.5
      )
    }
  }

  private var setCountPicker: some View {
    PlanningCountPicker(
      label: "组数",
      value: setCountBinding,
      range: 1...20,
      step: 1
    )
    .onChange(of: setCount) { _, _ in
      clampRestSecondsPerSet()
      clampPerSetTargets()
      syncSummaryFromPerSetTargets()
      persist()
    }
  }

  private var perSetTargetsEditor: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      ForEach(0..<max(1, setCount), id: \.self) { index in
        PerSetTargetRow(
          index: index,
          target: perSetTargetBinding(at: index),
          intensityMode: intensityMode,
          bases: viewModel.weightEntryBases(for: draftExercise)
        )
      }
    }
    .padding(.top, MeetPRSpacing.xs)
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

}

@available(iOS 17.0, macOS 14.0, *)
extension ExerciseSetEditorCard {
  private var perSetTargetsEnabledBinding: Binding<Bool> {
    Binding(
      get: { perSetTargets != nil },
      set: { isEnabled in
        if isEnabled {
          perSetTargets = normalizedPerSetTargets()
        } else {
          syncSummaryFromPerSetTargets()
          perSetTargets = nil
        }
        persist()
      }
    )
  }

  private func perSetTargetBinding(at index: Int) -> Binding<DraftSetTarget> {
    Binding(
      get: {
        let targets = normalizedPerSetTargets()
        guard targets.indices.contains(index) else { return defaultSetTarget }
        return targets[index]
      },
      set: { newValue in
        var targets = normalizedPerSetTargets()
        guard targets.indices.contains(index) else { return }
        targets[index] = normalizedTargetForCurrentMode(newValue)
        perSetTargets = targets
        syncSummaryFromPerSetTargets()
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
      targetValue: targetValue,
      restSeconds: restSeconds,
      restSecondsPerSet: restSecondsPerSet,
      perSetTargets: normalizedPerSetTargetsIfNeeded()
    )
  }

  private var defaultSetTarget: DraftSetTarget {
    DraftSetTarget(
      targetReps: targetReps,
      targetRepsMax: targetRepsMax,
      intensityMode: intensityMode,
      targetValue: targetValue
    )
  }

  private func normalizedPerSetTargetsIfNeeded() -> [DraftSetTarget]? {
    perSetTargets == nil ? nil : normalizedPerSetTargets()
  }

  private func normalizedPerSetTargets() -> [DraftSetTarget] {
    var targets = perSetTargets ?? []
    let desiredCount = max(1, setCount)
    if targets.count > desiredCount {
      targets.removeLast(targets.count - desiredCount)
    } else if targets.count < desiredCount {
      let fill = targets.last ?? defaultSetTarget
      targets.append(contentsOf: repeatElement(fill, count: desiredCount - targets.count))
    }
    return targets.map(normalizedTargetForCurrentMode)
  }

  private func normalizedTargetForCurrentMode(_ target: DraftSetTarget) -> DraftSetTarget {
    var next = target
    next.intensityMode = intensityMode
    next.targetReps = max(1, next.targetReps)
    if let targetRepsMax = next.targetRepsMax {
      next.targetRepsMax = max(next.targetReps, targetRepsMax)
    }
    switch intensityMode {
    case .weight:
      next.targetValue = max(Decimal(0), next.targetValue)
        .roundedToPlanningIncrement(PlanningDecimalStep.half)
    case .rpe:
      next.targetValue = min(Decimal(10), max(Decimal(1), next.targetValue))
        .roundedToPlanningIncrement(PlanningDecimalStep.half)
    }
    return next
  }

  private func clampPerSetTargets() {
    guard perSetTargets != nil else { return }
    perSetTargets = normalizedPerSetTargets()
  }

  private func syncSummaryFromPerSetTargets() {
    guard let first = normalizedPerSetTargetsIfNeeded()?.first else { return }
    targetReps = first.targetReps
    targetRepsMax = first.targetRepsMax
    intensityMode = first.intensityMode
    targetValue = first.targetValue
  }

  private func clampRestSecondsPerSet() {
    guard var values = restSecondsPerSet else { return }
    let desiredCount = max(1, setCount)
    if values.count > desiredCount {
      values.removeLast(values.count - desiredCount)
    } else if values.count < desiredCount {
      values.append(
        contentsOf: repeatElement(currentRestSeconds, count: desiredCount - values.count))
    }
    restSecondsPerSet = values
  }

  private var currentRestSeconds: Int {
    let target = normalizedPerSetTargetsIfNeeded()?.first ?? defaultSetTarget
    return restSeconds
      ?? RestDefaults.seconds(
        forRPE: target.intensityMode == .rpe ? target.targetValue : nil)
  }

  private func persist() {
    Task {
      try? await viewModel.updateW1SetSpec(currentSpec(), for: draftExercise.id)
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
    restSeconds = spec.restSeconds
    restSecondsPerSet = spec.restSecondsPerSet
    perSetTargets = spec.perSetTargets
    notes = draftExercise.notes ?? ""
  }
}
