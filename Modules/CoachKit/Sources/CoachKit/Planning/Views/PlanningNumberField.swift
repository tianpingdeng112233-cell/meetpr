import DesignSystem
import Foundation
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningNumberField: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  let decimalIncrement: Decimal
  let unitLabel: String?
  let formatStyle: FloatingPointFormatStyle<Double>

  @State private var textInput: String
  @FocusState private var isFocused: Bool

  init(
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    decimalIncrement: Decimal,
    unitLabel: String? = nil,
    formatStyle: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...1))
  ) {
    self._value = value
    self.range = range
    self.step = step
    self.decimalIncrement = decimalIncrement
    self.unitLabel = unitLabel
    self.formatStyle = formatStyle
    self._textInput = State(initialValue: value.wrappedValue.formatted(formatStyle))
  }

  var body: some View {
    HStack(alignment: .center, spacing: MeetPRSpacing.sm) {
      stepButton(systemName: "minus", accessibilityLabel: "减少", action: decrementTapped)
        .disabled(decrementDisabled)

      TextField("数值", text: $textInput)
        .planningDecimalKeyboard()
        .multilineTextAlignment(.center)
        .monospacedDigit()
        .padding(.horizontal, MeetPRSpacing.sm)
        .padding(.vertical, MeetPRSpacing.xs)
        .frame(width: 76)
        .background(Color.MeetPR.surface2)
        .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
        .focused($isFocused)
        .toolbar {
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("完成") {
              normalize()
              isFocused = false
            }
            .bold()
          }
        }
        .onChange(of: isFocused) { _, focused in
          if !focused {
            normalize()
          }
        }

      stepButton(systemName: "plus", accessibilityLabel: "增加", action: incrementTapped)
        .disabled(incrementDisabled)

      if let unitLabel {
        Text(unitLabel)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    }
    .onChange(of: value) { _, newValue in
      textInput = Self.syncedTextInput(
        currentTextInput: textInput,
        newValue: newValue,
        isFocused: isFocused,
        formatStyle: formatStyle
      )
    }
    .accessibilityElement(children: .combine)
    .accessibilityValue(accessibilityValue)
    .accessibilityRepresentation {
      Stepper(value: $value, in: range, step: step) {
        Text(accessibilityValue)
      }
    }
  }

  private var decrementDisabled: Bool {
    boundsReferenceValue <= range.lowerBound
  }

  private var incrementDisabled: Bool {
    boundsReferenceValue >= range.upperBound
  }

  private var boundsReferenceValue: Double {
    isFocused ? normalizedTextInput() : value
  }

  private var accessibilityValue: String {
    if let unitLabel {
      "\(formattedDisplay(value)), \(unitLabel)"
    } else {
      formattedDisplay(value)
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

  private func incrementTapped() {
    let next = Self.steppedValue(
      afterCommitting: textInput,
      range: range,
      step: step,
      decimalIncrement: decimalIncrement
    )
    value = next
    textInput = formattedDisplay(next)
  }

  private func decrementTapped() {
    let next = Self.steppedValue(
      afterCommitting: textInput,
      range: range,
      step: -step,
      decimalIncrement: decimalIncrement
    )
    value = next
    textInput = formattedDisplay(next)
  }

  private func normalize() {
    let normalized = normalizedTextInput()
    value = normalized
    textInput = formattedDisplay(normalized)
  }

  private func normalizedTextInput() -> Double {
    Self.normalizedValue(
      from: textInput,
      range: range,
      decimalIncrement: decimalIncrement
    )
  }

  private func formattedDisplay(_ newValue: Double) -> String {
    Self.formattedDisplay(newValue, formatStyle: formatStyle)
  }

  static func normalizedValue(
    from textInput: String,
    range: ClosedRange<Double>,
    decimalIncrement: Decimal
  ) -> Double {
    let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
    let parsed = trimmed.isEmpty ? 0 : Double(trimmed) ?? 0
    let rounded = Decimal.planningRounded(parsed, increment: decimalIncrement).planningDoubleValue
    return clamped(rounded, to: range)
  }

  static func steppedValue(
    afterCommitting textInput: String,
    range: ClosedRange<Double>,
    step: Double,
    decimalIncrement: Decimal
  ) -> Double {
    let committed = normalizedValue(
      from: textInput,
      range: range,
      decimalIncrement: decimalIncrement
    )
    let stepped = Decimal.planningRounded(
      committed + step,
      increment: decimalIncrement
    ).planningDoubleValue
    return clamped(stepped, to: range)
  }

  static func syncedTextInput(
    currentTextInput: String,
    newValue: Double,
    isFocused: Bool,
    formatStyle: FloatingPointFormatStyle<Double>
  ) -> String {
    if isFocused {
      currentTextInput
    } else {
      formattedDisplay(newValue, formatStyle: formatStyle)
    }
  }

  static func formattedDisplay(
    _ value: Double,
    formatStyle: FloatingPointFormatStyle<Double>
  ) -> String {
    value.formatted(formatStyle)
  }

  static func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
    min(max(value, range.lowerBound), range.upperBound)
  }
}

extension View {
  @ViewBuilder
  fileprivate func planningDecimalKeyboard() -> some View {
    #if os(iOS)
      keyboardType(.decimalPad)
    #else
      self
    #endif
  }
}
