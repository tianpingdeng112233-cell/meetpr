import SwiftUI

/// Bottom-sheet keypad defined by `NumberPad.dc.html`.
@MainActor
public struct MeetPRNumberPad: View {
  public enum Field: Equatable, Sendable {
    case weight
    case reps
  }

  let field: Field
  let initialValueText: String
  private let minimumWeight: Double
  private let onCommit: @MainActor (Double) -> Void
  private let onCancel: @MainActor () -> Void

  @State private var text = ""
  @State private var feedbackTrigger = 0

  public init(
    field: Field = .weight,
    value: Double,
    minimumWeight: Double = 20,
    onCommit: @escaping @MainActor (Double) -> Void,
    onCancel: @escaping @MainActor () -> Void
  ) {
    self.field = field
    self.initialValueText =
      field == .reps
      ? value.rounded().formatted(.number.precision(.fractionLength(0)))
      : value.formatted(.number.precision(.fractionLength(0...2)))
    self.minimumWeight = minimumWeight
    self.onCommit = onCommit
    self.onCancel = onCancel
  }

  /// Weight floor is caller-supplied: 20 fits barbell lifts (empty bar), but
  /// accessories (dumbbell/cable/bodyweight) legitimately go below — pass 0.
  public static func snapped(_ raw: Double, field: Field, minimumWeight: Double = 20) -> Double {
    switch field {
    case .weight:
      let clamped = min(max(raw, minimumWeight), 500)
      return (clamped * 4).rounded() / 4
    case .reps:
      return min(max(raw.rounded(), 1), 100)
    }
  }

  public var body: some View {
    // dc: header owns its 12pt bottom padding; the grid→buttons gap is 8.
    VStack(spacing: MeetPRSpacing.zero) {
      header

      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: MeetPRSpacing.space2), count: 3),
        spacing: MeetPRSpacing.space2
      ) {
        ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) {
          keypadButton($0)
        }
        keypadButton(".", isDisabled: field == .reps)
        keypadButton("0")
        deleteButton
      }

      HStack(spacing: MeetPRSpacing.space2) {
        Button(action: cancel) {
          Text("取消")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .overlay {
              Capsule()
                .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())

        Button(action: commit) {
          Text("确定")
            .font(.MeetPR.display(size: MeetPRFontMetrics.size15, weight: .extraBold))
            .foregroundStyle(Color.MeetPR.ctaText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
              // `linear-gradient(180deg, var(--gold-400), var(--gold-500))`
              LinearGradient(
                colors: [Color.MeetPR.gold400, Color.MeetPR.gold500],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
        }
        .buttonStyle(PressScaleButtonStyle())
        .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: MeetPRSpacing.space2)
      }
      // dc: `margin-top:8px` on the cancel/confirm row.
      .padding(.top, MeetPRSpacing.space2)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.top, MeetPRSpacing.point14)
    .padding(.bottom, MeetPRSpacing.point22)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(
      .rect(
        topLeadingRadius: MeetPRRadius.modal,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: MeetPRRadius.modal
      )
    )
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderDefault)
        .frame(height: 1)
    }
    .sensoryFeedback(.selection, trigger: feedbackTrigger)
  }

  private var header: some View {
    // dc: `padding:2px 4px 12px`; the unit hangs off the value at exactly 5pt.
    HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.zero) {
      Text(field == .reps ? "输入次数" : "输入重量")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .tracking(0.72)
        .foregroundStyle(Color.MeetPR.textMuted)

      Spacer()

      Text(text.isEmpty ? initialValueText : text)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size30, weight: .bold))
        .foregroundStyle(text.isEmpty ? Color.MeetPR.textFaint : Color.MeetPR.textPrimary)
        .multilineTextAlignment(.trailing)
        .frame(minWidth: 80)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(field == .weight ? "重量" : "次数")
        .accessibilityValue(text.isEmpty ? initialValueText : text)

      Text(field == .reps ? "次" : "KG")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.textMuted)
        .padding(.leading, MeetPRSpacing.point5)
    }
    .padding(.top, MeetPRSpacing.point2)
    .padding(.horizontal, MeetPRSpacing.space1)
    .padding(.bottom, MeetPRSpacing.space3)
  }

  private func keypadButton(_ character: String, isDisabled: Bool = false) -> some View {
    Button {
      append(character)
    } label: {
      Text(character)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size21, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.MeetPR.surfaceKey)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(PressScaleButtonStyle(isDisabled: isDisabled))
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.25 : 1)
    .accessibilityLabel(character == "." ? "小数点" : character)
  }

  private var deleteButton: some View {
    Button {
      guard !text.isEmpty else { return }
      text.removeLast()
      feedbackTrigger += 1
    } label: {
      Text("⌫")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size19, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.MeetPR.surfaceKey)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel("退格")
  }

  private func append(_ character: String) {
    if character == "." {
      guard field == .weight, !text.isEmpty, !text.contains("."), text.count <= 4 else {
        return
      }
      text.append(character)
    } else {
      let digitCount = text.filter(\.isNumber).count
      guard digitCount < (field == .reps ? 3 : 5) else { return }
      text = text == "0" ? character : text + character
    }
    feedbackTrigger += 1
  }

  private func cancel() {
    text = ""
    onCancel()
  }

  private func commit() {
    guard let rawValue = Double(text), !text.isEmpty else {
      cancel()
      return
    }
    let value = Self.snapped(rawValue, field: field, minimumWeight: minimumWeight)
    text = ""
    onCommit(value)
  }
}

#Preview("NumberPad · Weight + Reps · Dark") {
  VStack(spacing: MeetPRSpacing.space4) {
    MeetPRNumberPad(field: .weight, value: 175, onCommit: { _ in }, onCancel: {})
    MeetPRNumberPad(field: .reps, value: 3, onCommit: { _ in }, onCancel: {})
  }
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}

#Preview("NumberPad · Weight + Reps · Light") {
  VStack(spacing: MeetPRSpacing.space4) {
    MeetPRNumberPad(field: .weight, value: 175, onCommit: { _ in }, onCancel: {})
    MeetPRNumberPad(field: .reps, value: 3, onCommit: { _ in }, onCancel: {})
  }
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
