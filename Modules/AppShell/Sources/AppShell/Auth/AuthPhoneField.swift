import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AuthPhoneField: View {
  private let label: String
  private let prefix: String?
  private let placeholder: String
  private let errorMessage: String?

  @Binding private var text: String
  @FocusState private var isFocused: Bool

  init(
    _ label: String,
    text: Binding<String>,
    prefix: String? = "+86",
    placeholder: String = "",
    errorMessage: String? = nil
  ) {
    self.label = label
    self._text = text
    self.prefix = prefix
    self.placeholder = placeholder
    self.errorMessage = errorMessage
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point6) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
        Text(label)
          .font(.MeetPR.mono(size: 9.5, weight: .bold))
          .tracking(1.33)
          .foregroundStyle(labelColor)

        HStack(spacing: MeetPRSpacing.point10) {
          if let prefix {
            Text(prefix)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size17, weight: .medium))
              .foregroundStyle(Color.MeetPR.textTertiary)

            Rectangle()
              .fill(Color.MeetPR.borderStrong)
              .frame(width: MeetPRSpacing.point1, height: MeetPRSpacing.point18)
          }

          TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundStyle(Color.MeetPR.textDisabled)
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size18, weight: .medium))
          .tracking(0.72)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .tint(Color.MeetPR.gold500)
          .focused($isFocused)
          #if os(iOS)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
          #endif
          .accessibilityLabel(label)
          .accessibilityHint(errorMessage ?? AppShellStrings.phoneInputHint)
        }
      }
      .padding(.horizontal, MeetPRSpacing.point14)
      .padding(.vertical, MeetPRSpacing.space3)
      // 4a's phone card carries *only* the focus halo — unlike the password
      // card it has no diffuse drop shadow, so this deliberately does not go
      // through `meetPRCardSurface(.card)` (which would add `0 4px 18px @6%`).
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.point14)
          .stroke(borderColor, lineWidth: MeetPRSpacing.point1)
      }
      .overlay {
        if isFocused, errorMessage == nil {
          // `box-shadow: 0 0 0 3px` is a 3pt ring *outside* the border, so the
          // stroke is inset by half its width to sit flush with the edge.
          RoundedRectangle(cornerRadius: MeetPRRadius.point14)
            .inset(by: -MeetPRSpacing.point3 / 2)
            .stroke(Color.MeetPR.gold500.opacity(0.1), lineWidth: MeetPRSpacing.point3)
        }
      }

      if let errorMessage {
        Text(errorMessage)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.danger)
      }
    }
  }

  private var labelColor: Color {
    if errorMessage != nil {
      Color.MeetPR.danger
    } else if isFocused {
      Color.MeetPR.goldText
    } else {
      Color.MeetPR.textMuted
    }
  }

  private var borderColor: Color {
    if errorMessage != nil {
      Color.MeetPR.danger
    } else if isFocused {
      Color.MeetPR.gold500
    } else {
      Color.MeetPR.borderDefault
    }
  }
}
