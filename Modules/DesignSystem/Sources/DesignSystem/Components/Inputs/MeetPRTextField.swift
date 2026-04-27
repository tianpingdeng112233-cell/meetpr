import SwiftUI

@MainActor
public struct MeetPRTextField: View {
  private let label: String
  private let placeholder: String
  private let helperText: String?
  private let errorMessage: String?
  private let isMonospaced: Bool

  @Binding private var text: String
  @FocusState private var isFocused: Bool

  public init(
    _ label: String,
    text: Binding<String>,
    placeholder: String = "",
    helperText: String? = nil,
    errorMessage: String? = nil,
    isMonospaced: Bool = false
  ) {
    self.label = label
    self._text = text
    self.placeholder = placeholder
    self.helperText = helperText
    self.errorMessage = errorMessage
    self.isMonospaced = isMonospaced
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label.uppercased())
        .font(.system(size: MeetPRFontMetrics.captionSize, weight: .medium, design: .monospaced))
        .tracking(0.66)
        .foregroundStyle(errorMessage == nil ? Color.MeetPR.fgTertiary : Color.MeetPR.brandRed)

      TextField(placeholder, text: $text)
        .font(isMonospaced ? Font.MeetPR.monoLabel : Font.MeetPR.body)
        .tracking(isMonospaced ? 6.8 : 0)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .padding(MeetPRSpacing.md)
        .frame(minHeight: 44)
        .background(Color.MeetPR.surface1)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(borderColor, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        .focused($isFocused)
        .accessibilityLabel(label)
        .accessibilityHint(errorMessage ?? helperText ?? "Enter text.")

      if let message = errorMessage ?? helperText {
        Text(message)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(errorMessage == nil ? Color.MeetPR.fgSecondary : Color.MeetPR.brandRed)
      }
    }
  }

  private var borderColor: Color {
    if errorMessage != nil {
      Color.MeetPR.brandRed
    } else if isFocused {
      Color.MeetPR.fgPrimary
    } else {
      Color.MeetPR.border
    }
  }
}

#Preview("MeetPRTextField") {
  @Previewable @State var phone = "+86 138 0000 0000"
  @Previewable @State var code = "284913"
  @Previewable @State var error = "000000"

  VStack(spacing: MeetPRSpacing.base) {
    MeetPRTextField("Phone", text: $phone)
    MeetPRTextField("Verification Code", text: $code, isMonospaced: true)
    MeetPRTextField(
      "Code",
      text: $error,
      errorMessage: "Code expired. Request a new one.",
      isMonospaced: true
    )
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("MeetPRTextField Light") {
  @Previewable @State var phone = "+86 138 0000 0000"

  MeetPRTextField("Phone", text: $phone)
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
