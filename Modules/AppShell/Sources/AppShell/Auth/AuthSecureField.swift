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
  @State private var isPasswordVisible = false

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
    VStack(alignment: .leading, spacing: MeetPRSpacing.point6) {
      HStack(spacing: MeetPRSpacing.point10) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
          Text(label)
            .font(.MeetPR.mono(size: 9.5, weight: .bold))
            .tracking(1.33)
            .foregroundStyle(labelColor)

          Group {
            if isPasswordVisible {
              TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(Color.MeetPR.textDisabled)
              )
            } else {
              SecureField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(Color.MeetPR.textDisabled)
              )
            }
          }
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size18, weight: .semibold))
          .tracking(2.52)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .tint(Color.MeetPR.gold500)
          .focused($isFocused)
          #if os(iOS)
            .textContentType(.password)
          #endif
          .accessibilityLabel(label)
          .accessibilityHint(errorMessage ?? helperText ?? AppShellStrings.passwordInputHint)
        }

        Button {
          // Swapping SecureField↔TextField tears down the focused view, so the
          // keyboard would drop and the scroll offset would strand mid-avoid.
          // Re-assert focus on the next runloop tick if we had it.
          let wasFocused = isFocused
          isPasswordVisible.toggle()
          if wasFocused {
            Task { @MainActor in isFocused = true }
          }
        } label: {
          Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
            .font(.system(size: MeetPRFontMetrics.size17))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .frame(
              width: MeetPRSpacing.point34,
              height: MeetPRSpacing.point34
            )
            .background(Color.MeetPR.surfaceRaised)
            .clipShape(.rect(cornerRadius: MeetPRRadius.point9))
            // The mockup's chip is 34pt; grow the *tappable* area to the 44pt
            // minimum without letting it push the row wider.
            .frame(
              width: MeetPRSpacing.minimumHitTarget,
              height: MeetPRSpacing.minimumHitTarget
            )
            .contentShape(.rect)
            .padding(-(MeetPRSpacing.minimumHitTarget - MeetPRSpacing.point34) / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          isPasswordVisible ? AppShellStrings.hidePassword : AppShellStrings.showPassword
        )
      }
      .padding(.horizontal, MeetPRSpacing.point14)
      .padding(.vertical, MeetPRSpacing.space3)
      // 4a's password card draws `0 2px 10px rgba(17,24,39,.04)` — lighter and
      // tighter than `meetPRCardSurface(.card)`'s `0 4px 18px @6%`, so the
      // geometry is spelled out here. `cardShadow` is that same ink at 6% (and
      // `.clear` in dark), so scaling it by 2/3 lands on the mockup's 4% while
      // keeping the theme behaviour.
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
      .shadow(
        color: Color.MeetPR.cardShadow.opacity(2.0 / 3.0),
        radius: MeetPRSpacing.point5,
        y: MeetPRSpacing.point2
      )
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

      if let message = errorMessage ?? helperText {
        Text(message)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(
            errorMessage == nil
              ? Color.MeetPR.textTertiary
              : Color.MeetPR.danger
          )
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
