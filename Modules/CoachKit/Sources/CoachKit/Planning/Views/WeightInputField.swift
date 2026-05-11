import DesignSystem
import Foundation
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct WeightInputField: View {
  private let oneRM: Decimal?
  private let onChange: @MainActor (Decimal) -> Void

  @State private var inputUnit: WeightInputUnit
  @State private var inputValue: Double

  public init(
    value: Decimal,
    oneRM: Decimal?,
    onChange: @escaping @MainActor (Decimal) -> Void
  ) {
    self.oneRM = oneRM
    self.onChange = onChange
    self._inputUnit = State(initialValue: .kg)
    self._inputValue = State(initialValue: value.planningDoubleValue)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Picker("重量单位", selection: $inputUnit) {
        Text("kg").tag(WeightInputUnit.kg)
        Text("%1RM").tag(WeightInputUnit.percent)
      }
      .pickerStyle(.segmented)
      .disabled(oneRM == nil)
      .onChange(of: inputUnit) { oldValue, newValue in
        convertInput(from: oldValue, to: newValue)
      }

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
        TextField(inputUnit.title, value: $inputValue, format: .number)
          .monospacedDigit()
          .padding(MeetPRSpacing.sm)
          .background(Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
          .onChange(of: inputValue) { _, _ in
            publishValue()
          }

        Text(inputUnit.title)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }

      if inputUnit == .percent, let oneRM {
        Text("= \(displayKg(for: inputValue, oneRM: oneRM)) kg")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      } else if oneRM == nil {
        Eyebrow("未设 1RM，无法换算 %1RM", color: Color.MeetPR.fgTertiary, showsRule: false)
      }
    }
  }

  private func convertInput(from oldUnit: WeightInputUnit, to newUnit: WeightInputUnit) {
    guard oldUnit != newUnit else { return }
    guard let oneRM else {
      inputUnit = .kg
      return
    }

    guard oneRM > 0 else { return }
    switch newUnit {
    case .kg:
      inputValue = Self.percentToKg(inputValue, oneRM: oneRM).planningDoubleValue
    case .percent:
      inputValue = Self.kgToPercent(inputValue, oneRM: oneRM).planningDoubleValue
    }
    publishValue()
  }

  private func publishValue() {
    switch inputUnit {
    case .kg:
      onChange(Decimal.planningRounded(inputValue, increment: PlanningDecimalStep.half))
    case .percent:
      guard let oneRM else { return }
      onChange(Self.percentToKg(inputValue, oneRM: oneRM))
    }
  }

  private func displayKg(for percent: Double, oneRM: Decimal) -> String {
    Self.percentToKg(percent, oneRM: oneRM).planningFormatted()
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension WeightInputField {
  nonisolated static func kgToPercent(_ kg: Double, oneRM: Decimal) -> Decimal {
    guard oneRM > 0 else { return 0 }
    let rounded = Decimal.planningRounded(kg, increment: PlanningDecimalStep.half)
    return (rounded / oneRM * 100).roundedToPlanningIncrement(PlanningDecimalStep.half)
  }

  nonisolated static func percentToKg(_ percent: Double, oneRM: Decimal) -> Decimal {
    guard oneRM > 0 else { return 0 }
    let rounded = Decimal.planningRounded(percent, increment: PlanningDecimalStep.half)
    return (oneRM * rounded / 100).roundedToPlanningIncrement(PlanningDecimalStep.half)
  }
}

private enum WeightInputUnit: Hashable {
  // swiftlint:disable:next identifier_name
  case kg
  case percent

  var title: String {
    switch self {
    case .kg:
      "kg"
    case .percent:
      "%1RM"
    }
  }
}
