import CoreModels
import DesignSystem
import SwiftUI

/// A reference value offered by the weight panel: the student's 1RM or a
/// same-day main lift's target weight (变式/回组常按主项 top 组算,
/// David 2026-06-12). Tapping a chip drops the value into the expression.
public struct WeightEntryBase: Identifiable, Equatable, Sendable {
  public let id: String
  public let label: String
  public let amount: Decimal

  public init(id: String, label: String, amount: Decimal) {
    self.id = id
    self.label = label
    self.amount = amount
  }
}

/// 自绘重量计算器面板(David 2026-06-12):数字键 + 加减乘除 + ±2.5/±5
/// 步进 + 基数(1RM / 同日主项)插入与 % 快捷键。纯 UI——基数由调用方传入。
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct WeightEntryPanel: View {
  private let title: String
  private let bases: [WeightEntryBase]
  private let onCommit: @MainActor (Decimal) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draft: WeightEntryDraft
  @State private var selectedBaseID: String?

  public init(
    title: String,
    initialValue: Decimal,
    bases: [WeightEntryBase] = [],
    onCommit: @escaping @MainActor (Decimal) -> Void
  ) {
    self.title = title
    self.bases = bases
    self.onCommit = onCommit
    self._draft = State(initialValue: WeightEntryDraft(initialValue: initialValue))
    self._selectedBaseID = State(initialValue: bases.first?.id)
  }

  public var body: some View {
    // ScrollView keeps the pad reachable on small phones at the .fraction
    // detent; it stays put on anything taller (bounce only when needed).
    ScrollView {
      panelContent
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(Color.MeetPR.bg)
  }

  private var panelContent: some View {
    VStack(spacing: MeetPRSpacing.base) {
      Eyebrow(title)

      VStack(spacing: MeetPRSpacing.xs) {
        Text(draft.expressionText.isEmpty ? " " : draft.expressionText)
          .font(Font.MeetPR.footnote)
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.fgTertiary)

        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          Text(draft.displayText)
            .font(.system(size: 44, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("kg")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(CoachPlanningStrings.currentWeight(draft.displayText))

      if !bases.isEmpty {
        baseSection
      }

      stepperRow
      padGrid

      PrimaryButton(CoachPlanningStrings.enterWeight, isFullWidth: true) {
        onCommit(draft.value)
        dismiss()
      }
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.bg)
  }

  private var baseSection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      ScrollView(.horizontal) {
        HStack(spacing: MeetPRSpacing.sm) {
          ForEach(bases) { base in
            SelectableChip(
              title: "\(base.label) \(base.amount.planningFormatted())kg",
              isSelected: selectedBaseID == base.id
            ) {
              // Tap = drop the value into the expression (so 185 × 0.85
              // style math works) and aim the % quick keys at it.
              selectedBaseID = base.id
              draft.insert(amount: base.amount)
            }
          }
        }
      }
      .scrollIndicators(.hidden)

      if let base = bases.first(where: { $0.id == selectedBaseID }) {
        WeightPercentSection { percent in
          draft.apply(percent: percent, of: base.amount)
        }
      }
    }
  }

  private var stepperRow: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      stepButton("-5", delta: -5)
      stepButton("-2.5", delta: Decimal(-25) / 10)
      stepButton("+2.5", delta: Decimal(25) / 10)
      stepButton("+5", delta: 5)
    }
  }

  private func stepButton(_ label: String, delta: Decimal) -> some View {
    Button(label) {
      draft.step(by: delta)
    }
    .buttonStyle(.bordered)
    .font(Font.MeetPR.bodyEmphasis)
    .frame(maxWidth: .infinity)
  }

  private var padGrid: some View {
    Grid(horizontalSpacing: MeetPRSpacing.sm, verticalSpacing: MeetPRSpacing.sm) {
      GridRow {
        padButton("7") { draft.tapDigit(7) }
        padButton("8") { draft.tapDigit(8) }
        padButton("9") { draft.tapDigit(9) }
        operationButton(.divide)
      }
      GridRow {
        padButton("4") { draft.tapDigit(4) }
        padButton("5") { draft.tapDigit(5) }
        padButton("6") { draft.tapDigit(6) }
        operationButton(.multiply)
      }
      GridRow {
        padButton("1") { draft.tapDigit(1) }
        padButton("2") { draft.tapDigit(2) }
        padButton("3") { draft.tapDigit(3) }
        operationButton(.subtract)
      }
      GridRow {
        padButton(".") { draft.tapDot() }
        padButton("0") { draft.tapDigit(0) }
        padButton("⌫") { draft.tapBackspace() }
          .accessibilityLabel(CoachPlanningStrings.delete)
        operationButton(.add)
      }
    }
  }

  private func operationButton(_ operation: WeightEntryDraft.Operation) -> some View {
    Button {
      draft.tapOperation(operation)
    } label: {
      Text(operation.rawValue)
        .font(Font.MeetPR.title2)
        .frame(maxWidth: .infinity, minHeight: 52)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.MeetPR.brandRed)
    .background(Color.MeetPR.brandRedSoft)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .accessibilityLabel(CoachPlanningStrings.operation(operation.rawValue))
  }

  private func padButton(_ label: String, action: @escaping @MainActor () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(Font.MeetPR.title2)
        .monospacedDigit()
        .frame(maxWidth: .infinity, minHeight: 52)
    }
    .buttonStyle(.plain)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct SelectableChip: View {
  let title: String
  let isSelected: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(Font.MeetPR.footnote)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
    }
    .buttonStyle(.plain)
    .foregroundStyle(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.fgSecondary)
    .background(isSelected ? Color.MeetPR.brandRedSoft : Color.MeetPR.surface2)
    .clipShape(Capsule())
  }
}
