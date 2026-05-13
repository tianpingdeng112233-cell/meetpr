import DesignSystem
import Foundation
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningCountPicker: View {
  let label: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  let unitLabel: String?
  let formatStyle: FloatingPointFormatStyle<Double>
  @Binding var isExpanded: Bool

  init(
    label: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    unitLabel: String? = nil,
    formatStyle: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...1)),
    isExpanded: Binding<Bool>
  ) {
    self.label = label
    self._value = value
    self.range = range
    self.step = step
    self.unitLabel = unitLabel
    self.formatStyle = formatStyle
    self._isExpanded = isExpanded
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      labelRow

      if isExpanded {
        wheel
      }
    }
  }

  private var labelRow: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      } label: {
        HStack(spacing: 0) {
          Text(label)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Spacer(minLength: MeetPRSpacing.sm)
        }
        .contentShape(.rect)
        .padding(.vertical, MeetPRSpacing.sm)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityHint(isExpanded ? "已展开转盘,双击收起" : "双击展开转盘")

      stepButton(systemName: "minus", accessibilityLabel: "减少", action: decrementTapped)
        .disabled(decrementDisabled)

      Text(formattedDisplay(value))
        .font(Font.MeetPR.body)
        .monospacedDigit()
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(minWidth: 36)

      stepButton(systemName: "plus", accessibilityLabel: "增加", action: incrementTapped)
        .disabled(incrementDisabled)

      if let unitLabel {
        Text(unitLabel)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }

      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      } label: {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .frame(width: 28, height: 28)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isExpanded ? "收起转盘" : "展开转盘")
    }
  }

  private func stepButton(
    systemName: String,
    accessibilityLabel: String,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.footnote)
        .frame(width: 28, height: 28)
        .background(Color.MeetPR.surface2)
        .clipShape(.circle)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.MeetPR.fgPrimary)
    .accessibilityLabel(accessibilityLabel)
  }

  private func decrementTapped() {
    let currentTag = Self.tag(for: value, range: range, step: step)
    let nextTag = max(currentTag - 1, 0)
    value = Self.value(forTag: nextTag, range: range, step: step)
  }

  private func incrementTapped() {
    let currentTag = Self.tag(for: value, range: range, step: step)
    let nextTag = min(currentTag + 1, maxTag)
    value = Self.value(forTag: nextTag, range: range, step: step)
  }

  private var decrementDisabled: Bool {
    Self.tag(for: value, range: range, step: step) <= 0
  }

  private var incrementDisabled: Bool {
    Self.tag(for: value, range: range, step: step) >= maxTag
  }

  private var maxTag: Int {
    Self.tag(for: range.upperBound, range: range, step: step)
  }

  private var wheel: some View {
    Picker(label, selection: tagBinding) {
      ForEach(Self.tags(for: range, step: step), id: \.self) { tag in
        Text(formattedDisplay(Self.value(forTag: tag, range: range, step: step)))
          .monospacedDigit()
          .tag(tag)
      }
    }
    .planningWheelPickerStyle()
    .labelsHidden()
    .frame(height: 150)
  }

  private var tagBinding: Binding<Int> {
    Binding(
      get: { Self.tag(for: value, range: range, step: step) },
      set: { newTag in
        value = Self.value(forTag: newTag, range: range, step: step)
      }
    )
  }

  private var accessibilityLabel: String {
    let valueText = formattedDisplay(value)
    if let unitLabel {
      return "\(label) \(valueText), \(unitLabel)"
    }
    return "\(label) \(valueText)"
  }

  private func formattedDisplay(_ number: Double) -> String {
    number.formatted(formatStyle)
  }

  // MARK: - Testable static helpers

  /// All valid tag indices for the given range/step (inclusive of both bounds).
  /// Tag is an integer index into the grid; we use Int tags (not Double) to avoid
  /// SwiftUI Picker float-equality matching bugs.
  static func tags(for range: ClosedRange<Double>, step: Double) -> [Int] {
    let lastTag = max(0, tag(for: range.upperBound, range: range, step: step))
    return Array(0...lastTag)
  }

  /// Snap a Double value to its nearest Int tag index in the grid.
  static func tag(for value: Double, range: ClosedRange<Double>, step: Double) -> Int {
    guard step > 0 else { return 0 }
    let clamped = min(max(value, range.lowerBound), range.upperBound)
    return Int((clamped - range.lowerBound) / step + 0.5)
  }

  /// Inverse of `tag(for:range:step:)`.
  static func value(forTag tag: Int, range: ClosedRange<Double>, step: Double) -> Double {
    let raw = range.lowerBound + Double(tag) * step
    return min(max(raw, range.lowerBound), range.upperBound)
  }
}

extension View {
  @ViewBuilder
  fileprivate func planningWheelPickerStyle() -> some View {
    #if os(iOS)
      pickerStyle(.wheel)
    #else
      self
    #endif
  }
}
