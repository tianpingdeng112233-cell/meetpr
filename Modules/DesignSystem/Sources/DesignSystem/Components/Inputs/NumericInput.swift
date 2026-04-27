import SwiftUI

@frozen public enum MeetPRWeightUnit: String, CaseIterable, Sendable {
  // swiftlint:disable:next identifier_name
  case kg
  // swiftlint:disable:next identifier_name
  case lb

  var title: String {
    rawValue.uppercased()
  }

  var toggled: MeetPRWeightUnit {
    switch self {
    case .kg: .lb
    case .lb: .kg
    }
  }
}

@MainActor
public struct NumericInput: View {
  @Binding private var value: Double
  @Binding private var unit: MeetPRWeightUnit

  @State private var feedbackTrigger = 0

  public init(value: Binding<Double>, unit: Binding<MeetPRWeightUnit>) {
    self._value = value
    self._unit = unit
  }

  public var body: some View {
    VStack(spacing: MeetPRSpacing.md) {
      HStack(spacing: MeetPRSpacing.md) {
        NumericInputButton(label: "-", accessibilityLabel: "Decrease weight") {
          adjust(by: -2.5)
        }

        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          Text(formattedValue)
            .font(Font.MeetPR.displayNumeral)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .monospacedDigit()
            .minimumScaleFactor(0.7)

          Text(unit.title)
            .font(Font.MeetPR.displayUnit)
            .tracking(Font.MeetPR.displayUnitTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(formattedValue) \(unit.title)")
        .accessibilityHint("Current weight value.")

        NumericInputButton(label: "+", accessibilityLabel: "Increase weight") {
          adjust(by: 2.5)
        }
      }
      .padding(MeetPRSpacing.base)
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))

      HStack(spacing: MeetPRSpacing.sm) {
        NumericQuickAdjustButton(label: "-2.5") {
          adjust(by: -2.5)
        }
        NumericQuickAdjustButton(label: "-5") {
          adjust(by: -5)
        }
        NumericQuickAdjustButton(label: "+2.5") {
          adjust(by: 2.5)
        }
        NumericQuickAdjustButton(label: "+5") {
          adjust(by: 5)
        }
        NumericUnitToggleButton(action: toggleUnit)
      }
    }
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityElement(children: .contain)
  }

  private var formattedValue: String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }

  private func adjust(by delta: Double) {
    value += delta
    feedbackTrigger += 1
  }

  private func toggleUnit() {
    switch unit {
    case .kg:
      value *= 2.204_622_621_8
    case .lb:
      value /= 2.204_622_621_8
    }

    unit = unit.toggled
    feedbackTrigger += 1
  }
}

@MainActor
private struct NumericQuickAdjustButton: View {
  let label: String
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.system(size: MeetPRFontMetrics.captionSize, weight: .medium, design: .monospaced))
        .tracking(0.66)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(Color.MeetPR.surface2)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(MeetPRPressOpacityButtonStyle(isDisabled: false))
    .accessibilityLabel("Adjust weight by \(label)")
    .accessibilityHint("Changes the numeric weight value.")
  }
}

@MainActor
private struct NumericUnitToggleButton: View {
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text("KG <-> LB")
        .font(.system(size: MeetPRFontMetrics.captionSize, weight: .semibold, design: .monospaced))
        .tracking(0.66)
        .foregroundStyle(Color.MeetPR.bg)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(Color.MeetPR.fgPrimary)
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(MeetPRPressOpacityButtonStyle(isDisabled: false))
    .accessibilityLabel("Toggle unit")
    .accessibilityHint("Switches between kilograms and pounds.")
  }
}

@MainActor
private struct NumericInputButton: View {
  let label: String
  let accessibilityLabel: String
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(Font.MeetPR.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(width: 44, height: 44)
        .background(Color.MeetPR.surface2)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(MeetPRPressOpacityButtonStyle(isDisabled: false))
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Changes the numeric weight value.")
  }
}

#Preview("NumericInput") {
  @Previewable @State var value = 142.5
  @Previewable @State var unit = MeetPRWeightUnit.kg

  NumericInput(value: $value, unit: $unit)
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.dark)
}

#Preview("NumericInput Light") {
  @Previewable @State var value = 315.0
  @Previewable @State var unit = MeetPRWeightUnit.lb

  NumericInput(value: $value, unit: $unit)
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
