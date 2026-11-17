import SwiftUI

struct MeetPRAllDayNumberPad: View {
  let field: MeetPRNumberPad.Field
  let initialText: String
  let context: String
  let actions: MeetPRAllDayPadActions
  let onChange: (String) -> Void
  @State private var input: NumberPadTextInput?
  @State private var feedback = 0

  private var currentInput: NumberPadTextInput {
    input ?? NumberPadTextInput(value: initialText, field: field)
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      Text(context)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(3)
      if field == .rpe || field == .rir {
        MeetPRNumberPadQuickPicks(field: field, selected: currentInput.text) { value in
          input = NumberPadTextInput(value: value, field: field)
          onChange(value)
          feedback += 1
        }
      }
      HStack(spacing: MeetPRSpacing.space2) {
        Grid(horizontalSpacing: MeetPRSpacing.space2, verticalSpacing: MeetPRSpacing.space2) {
          ForEach(0..<3) { row in
            GridRow {
              ForEach(1..<4) { column in
                digit(String(row * 3 + column))
              }
            }
          }
          GridRow {
            digit(".", disabled: field == .reps || field == .rir)
            digit("0")
            Button {
              var value = currentInput
              value.deleteLast()
              change(value)
            } label: {
              Image(systemName: "delete.left")
                .font(.MeetPR.body(size: MeetPRFontMetrics.size19))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.MeetPR.surfaceKey, in: .rect(cornerRadius: MeetPRRadius.control))
            }
            .accessibilityLabel(DesignSystemStrings.backspace)
          }
        }
        .frame(maxWidth: .infinity)
        VStack(spacing: MeetPRSpacing.space2) {
          MeetPRNumberPadFunctionKey(
            title: DesignSystemStrings.numberPadAddSet, key: "add",
            action: actions.onAdd
          )
          .disabled(!actions.canAdd)
          .opacity(actions.canAdd ? 1 : 0.4)
          MeetPRNumberPadFunctionKey(
            title: DesignSystemStrings.numberPadFill,
            subtitle: DesignSystemStrings.numberPadUp, key: "fillUp",
            action: actions.onFillUp)
          MeetPRNumberPadFunctionKey(
            title: DesignSystemStrings.numberPadFill,
            subtitle: DesignSystemStrings.numberPadDown, key: "fillDown",
            action: actions.onFillDown)
          MeetPRNumberPadFunctionKey(
            title: actions.effortField == .rir ? "RIR" : "RPE", key: "effort",
            selected: field == .rpe || field == .rir, action: actions.onEffort)
        }
        .containerRelativeFrame(.horizontal, count: 4, spacing: MeetPRSpacing.space2)
      }
      .foregroundStyle(Color.MeetPR.textPrimary)
      .buttonStyle(PressScaleButtonStyle())
    }
    .sensoryFeedback(.selection, trigger: feedback)
  }

  private func digit(_ character: String, disabled: Bool = false) -> some View {
    Button {
      var value = currentInput
      value.append(character)
      change(value)
    } label: {
      Text(character)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size21, weight: .bold))
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.MeetPR.surfaceKey, in: .rect(cornerRadius: MeetPRRadius.control))
    }
    .disabled(disabled)
    .opacity(disabled ? 0.25 : 1)
    .accessibilityIdentifier("numberPad.digit.\(character)")
    .accessibilityLabel(character == "." ? DesignSystemStrings.decimalPoint : character)
  }

  private func change(_ value: NumberPadTextInput) {
    input = value
    onChange(value.text)
    feedback += 1
  }
}

private struct MeetPRNumberPadFunctionKey: View {
  let title: String
  var subtitle: String?
  let key: String
  var selected = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: MeetPRSpacing.space1) {
        Text(title).font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
        if let subtitle {
          Text(subtitle).font(.MeetPR.body(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .foregroundStyle(selected ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
      .background(
        selected ? Color.MeetPR.goldRGB.opacity(0.14) : Color.MeetPR.surfaceRaised,
        in: .rect(cornerRadius: MeetPRRadius.control)
      )
      .overlay {
        if selected {
          RoundedRectangle(cornerRadius: MeetPRRadius.control).strokeBorder(Color.MeetPR.gold500)
        }
      }
    }
    .accessibilityIdentifier("numberPad.\(key)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct MeetPRNumberPadQuickPicks: View {
  let field: MeetPRNumberPad.Field
  let selected: String
  let onSelect: (String) -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space1) {
      ForEach(
        field == .rir
          ? ["0", "1", "2", "3", "4", "5"]
          : ["6", "6.5", "7", "7.5", "8", "8.5", "9", "9.5", "10"], id: \.self
      ) { value in
        Button {
          onSelect(value)
        } label: {
          Text(value)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(
              Double(selected) == Double(value)
                ? Color.MeetPR.inkOnCTAFill : Color.MeetPR.textPrimary
            )
            .background(
              Double(selected) == Double(value)
                ? Color.MeetPR.gold500 : Color.MeetPR.surfaceKey,
              in: .rect(cornerRadius: MeetPRRadius.control))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier("numberPad.quick.\(value)")
        .accessibilityAddTraits(Double(selected) == Double(value) ? .isSelected : [])
      }
    }
  }
}
