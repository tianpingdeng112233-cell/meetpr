import DesignSystem
import Foundation
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct WeightInputField: View {
  private let oneRM: Decimal?
  private let bases: [WeightEntryBase]
  private let onChange: @MainActor (Decimal) -> Void

  @State private var inputUnit: WeightInputUnit
  @State private var inputValue: Double
  @State private var showPanel = false

  public init(
    value: Decimal,
    oneRM: Decimal?,
    bases: [WeightEntryBase] = [],
    onChange: @escaping @MainActor (Decimal) -> Void
  ) {
    self.oneRM = oneRM
    self.bases = bases
    self.onChange = onChange
    self._inputUnit = State(initialValue: .kg)
    self._inputValue = State(initialValue: value.planningDoubleValue)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Picker(CoachPlanningStrings.weightUnit, selection: $inputUnit) {
        Text("kg").tag(WeightInputUnit.kg)
        Text("%1RM").tag(WeightInputUnit.percent)
      }
      .pickerStyle(.segmented)
      .disabled(oneRM == nil)
      .onChange(of: inputUnit) { oldValue, newValue in
        convertInput(from: oldValue, to: newValue)
      }

      // Tap-to-edit (David 2026-06-12, B 形态): the value opens the weight
      // panel instead of the system keyboard.
      Button {
        showPanel = true
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          Text(
            Decimal.planningRounded(inputValue, increment: PlanningDecimalStep.half)
              .planningFormatted()
          )
          .monospacedDigit()
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(MeetPRSpacing.sm)
          .background(Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))

          Text(inputUnit.title)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
      .accessibilityLabel(CoachPlanningStrings.editWeight)
      .sheet(isPresented: $showPanel) {
        WeightEntryPanel(
          title: CoachPlanningStrings.targetWeight,
          initialValue: currentKgValue,
          bases: bases
        ) { kilograms in
          applyPanelValue(kilograms)
        }
        .presentationDetents([.fraction(0.75), .large])
      }

      if inputUnit == .percent, let oneRM {
        Text("= \(displayKg(for: inputValue, oneRM: oneRM)) kg")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      } else if oneRM == nil {
        Eyebrow(
          CoachPlanningStrings.missingOneRM,
          color: Color.MeetPR.fgTertiary,
          showsRule: false
        )
      }
    }
  }

  /// The panel always edits kg; mirror the current display unit on commit.
  private var currentKgValue: Decimal {
    switch inputUnit {
    case .kg:
      Decimal.planningRounded(inputValue, increment: PlanningDecimalStep.half)
    case .percent:
      oneRM.map { Self.percentToKg(inputValue, oneRM: $0) } ?? 0
    }
  }

  private func applyPanelValue(_ kilograms: Decimal) {
    // Publish the entered kg verbatim — the %-mode conversion below is
    // display-only, otherwise the kg→%→kg round-trip's double rounding
    // drifts the persisted weight (Codex review).
    let rounded = kilograms.roundedToPlanningIncrement(PlanningDecimalStep.half)
    switch inputUnit {
    case .kg:
      inputValue = rounded.planningDoubleValue
    case .percent:
      guard let oneRM, oneRM > 0 else {
        inputUnit = .kg
        inputValue = rounded.planningDoubleValue
        break
      }
      inputValue =
        Self.kgToPercent(rounded.planningDoubleValue, oneRM: oneRM)
        .planningDoubleValue
    }
    onChange(rounded)
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
  nonisolated static func kgToPercent(_ kilograms: Double, oneRM: Decimal) -> Decimal {
    guard oneRM > 0 else { return 0 }
    let rounded = Decimal.planningRounded(kilograms, increment: PlanningDecimalStep.half)
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
