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
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        isExpanded.toggle()
      }
    } label: {
      HStack(spacing: MeetPRSpacing.sm) {
        Text(label)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        Spacer()

        Text(formattedDisplay(value))
          .font(Font.MeetPR.body)
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.fgPrimary)

        if let unitLabel {
          Text(unitLabel)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }

        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      .contentShape(.rect)
      .padding(.vertical, MeetPRSpacing.sm)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(isExpanded ? "已展开转盘" : "双击展开转盘")
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
