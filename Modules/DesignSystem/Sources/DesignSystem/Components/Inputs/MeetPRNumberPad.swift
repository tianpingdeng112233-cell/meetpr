import SwiftUI

/// The bottom-sheet keypad from the handoff `NumberPad` contract.
///
/// Three columns, 52pt keys, mono display. Reps mode disables the decimal key
/// outright. Commit snaps instead of validating loudly: weight to the nearest
/// 0.25kg inside 20–500, reps to a whole number inside 1–100. Cancel (or the
/// sheet's drag-down) writes nothing back.
public struct MeetPRNumberPad: View {
  public enum Field {
    case weight
    case reps
  }

  private let field: Field
  private let onCommit: (Double) -> Void
  private let onCancel: () -> Void

  @State private var text: String
  @State private var feedback = 0

  public init(
    field: Field,
    value: Double,
    onCommit: @escaping (Double) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.field = field
    self.onCommit = onCommit
    self.onCancel = onCancel
    let initial =
      field == .reps
      ? String(Int(value.rounded()))
      : (value == value.rounded() ? String(Int(value)) : String(value))
    self._text = State(initialValue: initial)
  }

  private var allowsDecimal: Bool { field == .weight }

  private var unitLabel: String { field == .weight ? "KG" : "次" }

  /// Snap per the contract: weight → 0.25kg multiples in 20...500,
  /// reps → integers in 1...100.
  public static func snapped(_ raw: Double, field: Field) -> Double {
    switch field {
    case .weight:
      let clamped = min(max(raw, 20), 500)
      return (clamped * 4).rounded() / 4
    case .reps:
      return min(max(raw.rounded(), 1), 100)
    }
  }

  public var body: some View {
    VStack(spacing: MeetPRSpacing.space4) {
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space2) {
        Text(text.isEmpty ? "0" : text)
          .font(.MeetPR.mono(size: 34, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .contentTransition(.numericText())
          .accessibilityLabel("\(text.isEmpty ? "0" : text) \(unitLabel)")
        Text(unitLabel)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.textMuted)
        Spacer()
        Button("取消", action: onCancel)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(minWidth: 44, minHeight: 44)
      }

      Grid(horizontalSpacing: MeetPRSpacing.space2, verticalSpacing: MeetPRSpacing.space2) {
        ForEach(0..<3, id: \.self) { row in
          GridRow {
            ForEach(1...3, id: \.self) { column in
              key("\(row * 3 + column)")
            }
          }
        }
        GridRow {
          key(".", disabled: !allowsDecimal)
          key("0")
          deleteKey
        }
      }

      Button {
        let raw = Double(text) ?? 0
        onCommit(Self.snapped(raw, field: field))
      } label: {
        Text("确认")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
          .foregroundStyle(Color.MeetPR.ctaText)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(Color.MeetPR.ctaBackground)
          .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
      }
      .buttonStyle(PressScaleButtonStyle())
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceElevated)
    .sensoryFeedback(.selection, trigger: feedback)
  }

  private func key(_ digit: String, disabled: Bool = false) -> some View {
    Button {
      tap(digit)
    } label: {
      Text(digit)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size18, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.MeetPR.surfaceKey)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(disabled)
    .opacity(disabled ? 0.25 : 1)
  }

  private var deleteKey: some View {
    Button {
      guard !text.isEmpty else { return }
      text.removeLast()
      feedback += 1
    } label: {
      Image(systemName: "delete.backward")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.MeetPR.surfaceKey)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel("删除")
  }

  private func tap(_ digit: String) {
    if digit == "." {
      guard allowsDecimal, !text.contains(".") else { return }
      text = text.isEmpty ? "0." : text + "."
    } else {
      // Cap total length; nobody lifts a 5-digit kilo number.
      guard text.count < 6 else { return }
      text = (text == "0" ? "" : text) + digit
    }
    feedback += 1
  }
}
