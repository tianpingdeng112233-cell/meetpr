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

  @State private var showWheel = false

  init(
    label: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    unitLabel: String? = nil,
    formatStyle: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...1))
  ) {
    self.label = label
    self._value = value
    self.range = range
    self.step = step
    self.unitLabel = unitLabel
    self.formatStyle = formatStyle
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.xs) {
      HStack(spacing: MeetPRSpacing.xs) {
        Text(label)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)

        if let unitLabel {
          Text(unitLabel)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }

      HStack(spacing: MeetPRSpacing.sm) {
        stepButton(systemName: "minus", accessibilityLabel: "减少", action: decrementTapped)
          .disabled(decrementDisabled)

        Button {
          showWheel = true
        } label: {
          Text(formattedDisplay(value))
            .font(Font.MeetPR.body)
            .monospacedDigit()
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(minWidth: 44)
            .padding(.horizontal, MeetPRSpacing.sm)
            .padding(.vertical, MeetPRSpacing.xs)
            .background(Color.MeetPR.surface2)
            .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)

        stepButton(systemName: "plus", accessibilityLabel: "增加", action: incrementTapped)
          .disabled(incrementDisabled)
      }
    }
    .frame(maxWidth: .infinity)
    .sheet(isPresented: $showWheel) {
      wheelSheet
        .planningWheelSheetDetents()
    }
  }

  private var wheelSheet: some View {
    NavigationStack {
      VStack(spacing: 0) {
        wheel
          .frame(maxWidth: .infinity)
          .padding()
        Spacer(minLength: 0)
      }
      .navigationTitle(label)
      .planningInlineTitle()
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { showWheel = false }
        }
      }
    }
  }

  private var wheel: some View {
    Picker(label, selection: tagBinding) {
      ForEach(Self.tags(for: range, step: step), id: \.self) { tag in
        Text(formattedDisplay(Self.value(forTag: tag, range: range, step: step)))
          .font(Font.MeetPR.bodyEmphasis)
          .monospacedDigit()
          .tag(tag)
      }
    }
    .planningWheelPickerStyle()
    .labelsHidden()
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

  @ViewBuilder
  fileprivate func planningWheelSheetDetents() -> some View {
    #if os(iOS)
      presentationDetents([.medium])
    #else
      self
    #endif
  }

  @ViewBuilder
  fileprivate func planningInlineTitle() -> some View {
    #if os(iOS)
      navigationBarTitleDisplayMode(.inline)
    #else
      self
    #endif
  }
}
