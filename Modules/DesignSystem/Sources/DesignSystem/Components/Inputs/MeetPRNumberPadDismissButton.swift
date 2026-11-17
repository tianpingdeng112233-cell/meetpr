import SwiftUI

struct MeetPRNumberPadDismissButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "keyboard.chevron.compact.down")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size19))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(width: 48, height: 44)
        .background(Color.MeetPR.surfaceRaised, in: .rect(cornerRadius: 12))
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(DesignSystemStrings.numberPadDismissKeyboard)
    .accessibilityIdentifier("numberPad.dismiss")
    .offset(y: -48)
    .padding(.trailing, MeetPRSpacing.space4)
  }
}
