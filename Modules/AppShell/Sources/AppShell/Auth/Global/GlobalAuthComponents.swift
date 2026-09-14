import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GlobalAuthHero: View {
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point18) {
      MeetPRMark(fontSize: MeetPRFontMetrics.size15)

      VStack(alignment: .leading, spacing: 0) {
        Text(title)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size44, weight: .extraBold))
          .tracking(-1.1)
          .lineSpacing(-5.6326)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .fixedSize(horizontal: false, vertical: true)

        Rectangle()
          .fill(Color.MeetPR.gold500)
          .frame(width: 44, height: MeetPRSpacing.point3)
          .clipShape(.rect(cornerRadius: MeetPRSpacing.point2))
          .padding(.top, MeetPRSpacing.space4)
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct GlobalEmailField: View {
  private let label: String
  private let placeholder: String
  private let errorMessage: String?

  @Binding private var text: String
  @FocusState private var isFocused: Bool

  init(
    _ label: String,
    text: Binding<String>,
    placeholder: String,
    errorMessage: String? = nil
  ) {
    self.label = label
    _text = text
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

        TextField(
          "",
          text: $text,
          prompt: Text(placeholder).foregroundStyle(Color.MeetPR.textDisabled)
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .tint(Color.MeetPR.gold500)
        .globalEmailInputTraits()
        .focused($isFocused)
        #if os(iOS)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
        #endif
        .accessibilityLabel(label)
      }
      .padding(.horizontal, MeetPRSpacing.point14)
      .padding(.vertical, MeetPRSpacing.space3)
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
      Color.MeetPR.danger.opacity(0.5)
    } else if isFocused {
      Color.MeetPR.gold500
    } else {
      Color.MeetPR.borderSubtle
    }
  }
}

extension View {
  @ViewBuilder
  fileprivate func globalEmailInputTraits() -> some View {
    #if os(iOS)
      textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    #else
      self
    #endif
  }

  @ViewBuilder
  func globalInlineNavigationTitle() -> some View {
    #if os(iOS)
      navigationBarTitleDisplayMode(.inline)
    #else
      self
    #endif
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct GlobalAuthButton: View {
  let title: String
  let isLoading: Bool
  let isDisabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.space2) {
        if isLoading {
          ProgressView()
            .tint(Color.MeetPR.inkOnGold)
        } else {
          Text(title)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
            .tracking(0.32)
          Image(systemName: "arrow.right")
            .font(.system(size: MeetPRFontMetrics.size16, weight: .bold))
        }
      }
      .foregroundStyle(isDisabled ? Color.MeetPR.textDisabled : Color.MeetPR.inkOnGold)
      .frame(maxWidth: .infinity)
      .frame(height: 54)
      .background(isDisabled ? Color.MeetPR.surfaceRaised : Color.MeetPR.gold500)
      .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
      .shadow(
        color: isDisabled ? .clear : Color.MeetPR.gold500.opacity(0.22),
        radius: MeetPRSpacing.point9,
        y: MeetPRSpacing.point6
      )
    }
    .disabled(isDisabled)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct GlobalAuthToast: View {
  let message: String
  let color: Color

  init(message: String, color: Color = Color.MeetPR.danger) {
    self.message = message
    self.color = color
  }

  var body: some View {
    Text(message)
      .font(Font.MeetPR.footnote)
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct GlobalAuthBackground: View {
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.MeetPR.bgBase
        RadialGradient(
          stops: [
            .init(color: Color.MeetPR.gold500.opacity(0.08), location: 0),
            .init(color: Color.MeetPR.gold500.opacity(0), location: 0.7),
          ],
          center: .top,
          startRadius: 0,
          endRadius: 1
        )
        .scaleEffect(
          x: proxy.size.width * 0.9,
          y: proxy.size.height * 0.44,
          anchor: .top
        )
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}
