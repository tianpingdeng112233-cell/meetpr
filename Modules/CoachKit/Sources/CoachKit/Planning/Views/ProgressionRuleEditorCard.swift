import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct ProgressionRuleEditorCard: View {
  @Bindable private var viewModel: PlanningViewModel
  @State private var rule: DraftProgressionRule

  public init(viewModel: PlanningViewModel, rule: DraftProgressionRule) {
    self.viewModel = viewModel
    self._rule = State(initialValue: rule)
  }

  public var body: some View {
    Card(accessibilityLabel: "Progression rule editor") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        header
        typePicker

        if rule.ruleType == .custom {
          customControls
        } else {
          incrementControl
        }

        chipSection(title: "应用动作") {
          ForEach(viewModel.sortedDraftExercises, id: \.id) { exercise in
            RuleChip(
              title: viewModel.exerciseName(for: exercise),
              isSelected: rule.exerciseIDs.contains(exercise.id),
              isDisabled: false
            ) {
              Task {
                try? await viewModel.toggleRuleExercise(exercise.id, for: rule.id)
                syncFromViewModel()
              }
            }
          }
        }

        chipSection(title: "应用周") {
          RuleChip(title: "W1", isSelected: false, isDisabled: true) {}
          ForEach([2, 3, 4], id: \.self) { week in
            RuleChip(
              title: "W\(week)",
              isSelected: rule.appliedWeeks.contains(week),
              isDisabled: (viewModel.planWeeks ?? 4) < week
            ) {
              Task {
                try? await viewModel.toggleAppliedWeek(week, for: rule.id)
                syncFromViewModel()
              }
            }
          }
        }
      }
      .onChange(of: rule.ruleType) { _, _ in persistRule() }
      .onChange(of: rule.customDimension) { _, _ in persistRule() }
      .onChange(of: rule.incrementValue) { _, _ in persistRule() }
      .onChange(of: rule.customSequence) { _, _ in persistRule() }
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("规则 \(rule.displayOrder + 1)")
        .font(Font.MeetPR.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      if viewModel.isRuleOverridden(rule) {
        StatusBadge(status: .overdue, title: "被覆盖")
      }

      Spacer()

      Button("删除", systemImage: "trash") {
        Task {
          try? await viewModel.deleteRule(id: rule.id)
        }
      }
      .font(Font.MeetPR.footnote)
      .foregroundStyle(Color.MeetPR.brandRed)
      .buttonStyle(.borderless)
    }
  }

  private var typePicker: some View {
    Picker("规则类型", selection: $rule.ruleType) {
      ForEach(ProgressionRuleType.allCases, id: \.self) { type in
        Text(type.title).tag(type)
      }
    }
    .pickerStyle(.menu)
  }

  private var incrementControl: some View {
    Stepper(value: incrementBinding, in: 0...100, step: incrementStep) {
      HStack {
        Text("增减量")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Spacer()
        Text(incrementLabel)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .monospacedDigit()
      }
    }
  }

  private var customControls: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Picker("自定义维度", selection: customDimensionBinding) {
        ForEach(ProgressionRuleDimension.allCases, id: \.self) { dimension in
          Text(dimension.title).tag(dimension)
        }
      }
      .pickerStyle(.segmented)

      ForEach(rule.appliedWeeks.sorted(), id: \.self) { week in
        let index = rule.appliedWeeks.sorted().firstIndex(of: week) ?? 0
        Stepper(value: customValueBinding(index: index), in: 0...300, step: customStep) {
          HStack {
            Text("W\(week) 值")
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
            Spacer()
            Text(customValueLabel(index: index))
              .font(Font.MeetPR.bodyEmphasis)
              .foregroundStyle(Color.MeetPR.fgPrimary)
              .monospacedDigit()
          }
        }
      }
    }
  }

  private func chipSection<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow(title, color: Color.MeetPR.fgTertiary, showsRule: false)
      ScrollView(.horizontal) {
        HStack(spacing: MeetPRSpacing.sm) {
          content()
        }
        .padding(.vertical, 1)
      }
      .scrollIndicators(.hidden)
    }
  }

  private var incrementBinding: Binding<Double> {
    Binding(
      get: { NSDecimalNumber(decimal: rule.incrementValue ?? 0).doubleValue },
      set: { rule.incrementValue = Decimal($0) }
    )
  }

  private var customDimensionBinding: Binding<ProgressionRuleDimension> {
    Binding(
      get: { rule.customDimension ?? .weight },
      set: { rule.customDimension = $0 }
    )
  }

  private func customValueBinding(index: Int) -> Binding<Double> {
    Binding(
      get: {
        guard let sequence = rule.customSequence, sequence.indices.contains(index) else { return 0 }
        return NSDecimalNumber(decimal: sequence[index]).doubleValue
      },
      set: { value in
        var sequence = rule.customSequence ?? []
        while sequence.count <= index {
          sequence.append(0)
        }
        sequence[index] = Decimal(value)
        rule.customSequence = sequence
      }
    )
  }

  private var incrementStep: Double {
    switch rule.ruleType.dimension {
    case .rpe:
      0.5
    case .sets, .reps:
      1
    case .weight, nil:
      2.5
    }
  }

  private var customStep: Double {
    switch rule.customDimension {
    case .rpe:
      0.5
    case .sets, .reps:
      1
    case .weight, nil:
      2.5
    }
  }

  private var incrementLabel: String {
    let value = NSDecimalNumber(decimal: rule.incrementValue ?? 0).doubleValue
    return value.formatted(.number.precision(.fractionLength(0...1)))
  }

  private func customValueLabel(index: Int) -> String {
    guard let sequence = rule.customSequence, sequence.indices.contains(index) else { return "0" }
    let value = NSDecimalNumber(decimal: sequence[index]).doubleValue
    return value.formatted(.number.precision(.fractionLength(0...1)))
  }

  private func persistRule() {
    Task {
      try? await viewModel.updateRule(rule)
      syncFromViewModel()
    }
  }

  private func syncFromViewModel() {
    guard let updated = viewModel.progressionRules.first(where: { $0.id == rule.id }) else {
      return
    }
    rule = updated
  }
}

@MainActor
private struct RuleChip: View {
  let title: String
  let isSelected: Bool
  let isDisabled: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(isSelected ? Color.MeetPR.bg : Color.MeetPR.fgPrimary)
        .lineLimit(1)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.surface2)
        .overlay {
          Capsule()
            .stroke(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(.capsule)
        .opacity(isDisabled ? 0.35 : 1)
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .accessibilityLabel(title)
  }
}

extension ProgressionRuleDimension {
  fileprivate var title: String {
    switch self {
    case .weight:
      "重量"
    case .rpe:
      "RPE"
    case .sets:
      "组数"
    case .reps:
      "次数"
    }
  }
}
