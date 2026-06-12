import CoreModels
import DesignSystem
import SwiftUI

/// A percentage base offered by the weight panel: the student's 1RM or a
/// same-day main lift's target weight (变式/回组按主项 top 组算,
/// David 2026-06-12).
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

/// Editing state for the panel, kept off the view so the pad/stepper/percent
/// rules test in isolation. Values are kg on a 0.5 grid; %-of-base results
/// land on the plate-realistic 2.5 grid.
struct WeightEntryDraft: Equatable {
  private(set) var text: String

  init(initialValue: Decimal) {
    text = initialValue > 0 ? initialValue.planningFormatted() : ""
  }

  var displayText: String { text.isEmpty ? "0" : text }

  var value: Decimal {
    Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? 0
  }

  mutating func tapDigit(_ digit: Int) {
    guard (0...9).contains(digit) else { return }
    // One decimal place max — planning weights live on a 0.5 grid.
    if let dotIndex = text.firstIndex(of: "."), text.index(after: dotIndex) < text.endIndex {
      return
    }
    if text == "0" { text = "" }
    guard text.count < 6 else { return }
    text.append(String(digit))
  }

  mutating func tapDot() {
    guard !text.contains(".") else { return }
    text = text.isEmpty ? "0." : text + "."
  }

  mutating func tapBackspace() {
    guard !text.isEmpty else { return }
    text.removeLast()
  }

  mutating func step(by delta: Decimal) {
    let next = max(0, value + delta)
    text = next.roundedToPlanningIncrement(PlanningDecimalStep.half).planningFormatted()
  }

  mutating func apply(percent: Int, of base: Decimal) {
    guard base > 0, percent > 0 else { return }
    let raw = base * Decimal(percent) / 100
    text = raw.roundedToPlanningIncrement(PlanningDecimalStep.plate).planningFormatted()
  }
}

/// 自绘重量输入面板(David 2026-06-12,B 形态):大号数字键 + ±2.5/±5 步进
/// + 按基数 % 换算。纯 UI——基数(1RM / 同日主项)由调用方传入。
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct WeightEntryPanel: View {
  private let title: String
  private let bases: [WeightEntryBase]
  private let onCommit: @MainActor (Decimal) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draft: WeightEntryDraft
  @State private var selectedBaseID: String?

  private static let percents = [60, 70, 75, 80, 85, 90]

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

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
        Text(draft.displayText)
          .font(.system(size: 44, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("kg")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      .frame(maxWidth: .infinity)
      .accessibilityLabel("当前重量 \(draft.displayText) kg")

      if !bases.isEmpty {
        baseSection
      }

      stepperRow
      padGrid

      PrimaryButton("填入", isFullWidth: true) {
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
              selectedBaseID = selectedBaseID == base.id ? nil : base.id
            }
          }
        }
      }
      .scrollIndicators(.hidden)

      if let base = bases.first(where: { $0.id == selectedBaseID }) {
        ScrollView(.horizontal) {
          HStack(spacing: MeetPRSpacing.sm) {
            ForEach(Self.percents, id: \.self) { percent in
              Button("\(percent)%") {
                draft.apply(percent: percent, of: base.amount)
              }
              .buttonStyle(.bordered)
              .font(Font.MeetPR.footnote)
              .tint(Color.MeetPR.brandRed)
            }
          }
        }
        .scrollIndicators(.hidden)
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
      ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
        GridRow {
          ForEach(row, id: \.self) { digit in
            padButton("\(digit)") { draft.tapDigit(digit) }
          }
        }
      }
      GridRow {
        padButton(".") { draft.tapDot() }
        padButton("0") { draft.tapDigit(0) }
        padButton("⌫") { draft.tapBackspace() }
          .accessibilityLabel("删除")
      }
    }
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
