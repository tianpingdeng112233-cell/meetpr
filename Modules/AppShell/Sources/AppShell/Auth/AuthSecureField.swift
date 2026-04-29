import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AuthSecureField: View {
  private let label: String
  private let placeholder: String
  private let helperText: String?
  private let errorMessage: String?

  @Binding private var text: String
  @FocusState private var isFocused: Bool

  init(
    _ label: String,
    text: Binding<String>,
    placeholder: String = "",
    helperText: String? = nil,
    errorMessage: String? = nil
  ) {
    self.label = label
    self._text = text
    self.placeholder = placeholder
    self.helperText = helperText
    self.errorMessage = errorMessage
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label.uppercased())
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(errorMessage == nil ? Color.MeetPR.fgTertiary : Color.MeetPR.brandRed)

      SecureField(placeholder, text: $text)
        .font(Font.MeetPR.body)
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
        .accessibilityHint(errorMessage ?? helperText ?? "Enter secure text.")

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
