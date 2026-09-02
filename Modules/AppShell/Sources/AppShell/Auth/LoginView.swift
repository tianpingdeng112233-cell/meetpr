import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct LoginView: View {
  @Environment(Session.self) private var session
  @State private var viewModel = AuthFormViewModel(mode: .login)

  public init() {}

  public var body: some View {
    @Bindable var viewModel = viewModel

    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point18) {
            MeetPRMark(fontSize: MeetPRFontMetrics.size15)

            VStack(alignment: .leading, spacing: 0) {
              Text("Better than\nyesterday")
                .font(
                  .MeetPR.display(
                    size: MeetPRFontMetrics.size44,
                    weight: .extraBold
                  )
                )
                .tracking(-1.1)
                // CSS `line-height:.96` on 44px wants a 42.24pt line box, but
                // `lineSpacing` *adds* to the font's own line height. Archivo-VF
                // measures ascent 38.6323 + descent 9.2403 + leading 0 = 47.8726
                // at 44pt (CoreText), so the delta is 42.24 − 47.8726.
                .lineSpacing(Metrics.headlineLineSpacing)
                .foregroundStyle(Color.MeetPR.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

              Rectangle()
                .fill(Color.MeetPR.gold500)
                .frame(width: Metrics.goldRuleWidth, height: MeetPRSpacing.point3)
                .clipShape(.rect(cornerRadius: MeetPRSpacing.point2))
                .padding(.top, MeetPRSpacing.space4)
            }
          }

          Spacer(minLength: MeetPRSpacing.space6)

          VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
            Text(AppShellStrings.loginInstructions)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textTertiary)

            AuthPhoneField(
              AppShellStrings.phoneNumber,
              text: $viewModel.phone,
              prefix: viewModel.phonePrefix,
              placeholder: viewModel.loginPhonePlaceholder,
              errorMessage: viewModel.phoneError
            )
            .accessibilityIdentifier("login.phone")

            // No placeholder: at mono 18/semibold any prompt reads as a
            // pre-filled password (the mockup only ever draws the filled
            // state), and the mono label above already names the field.
            AuthSecureField(
              AppShellStrings.password,
              text: $viewModel.password,
              errorMessage: viewModel.passwordError
            )
            .accessibilityIdentifier("login.password")

            if let toastMessage = viewModel.toastMessage {
              Text(toastMessage)
                .font(Font.MeetPR.footnote)
                .foregroundStyle(Color.MeetPR.danger)
                .accessibilityIdentifier("login.toast")
            }

            let isSubmitDisabled = !viewModel.canSubmit || viewModel.isSubmitting

            Button {
              Task {
                await viewModel.submit(using: session)
              }
            } label: {
              HStack(spacing: MeetPRSpacing.space2) {
                if viewModel.isSubmitting {
                  ProgressView()
                    .tint(Color.MeetPR.inkOnGold)
                } else {
                  Text(AppShellStrings.signIn)
                    .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
                    .tracking(0.32)

                  Image(systemName: "arrow.right")
                    .font(.system(size: MeetPRFontMetrics.size16, weight: .bold))
                }
              }
              // The mockup only draws 4a's enabled CTA, so the disabled
              // treatment comes from its own 4b 「下一步」 slab: a raised
              // surface under disabled ink, and no gold glow.
              .foregroundStyle(
                isSubmitDisabled ? Color.MeetPR.textDisabled : Color.MeetPR.inkOnGold
              )
              .frame(maxWidth: .infinity)
              .frame(height: Metrics.ctaHeight)
              .background(
                isSubmitDisabled ? Color.MeetPR.surfaceRaised : Color.MeetPR.gold500
              )
              .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
              .shadow(
                color: isSubmitDisabled
                  ? .clear
                  : Color.MeetPR.gold500.opacity(0.22),
                radius: MeetPRSpacing.point9,
                y: MeetPRSpacing.point6
              )
            }
            .disabled(isSubmitDisabled)
            .accessibilityIdentifier("login.submit")

            HStack(spacing: MeetPRSpacing.space1) {
              Text(AppShellStrings.consent)
                .foregroundStyle(Color.MeetPR.textMuted)

              Link(
                AppShellStrings.privacyPolicy,
                destination: AnalyticsPrivacyNotice.privacyPolicyURL
              )
              .foregroundStyle(Color.MeetPR.goldText)
              .underline()
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, MeetPRSpacing.space6)
        .padding(.top, Metrics.heroTopInset)
        .padding(.bottom, MeetPRSpacing.point26)
        .frame(maxWidth: 520, alignment: .leading)
        .frame(
          maxWidth: .infinity,
          minHeight: proxy.size.height,
          alignment: .top
        )
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .background {
      GeometryReader { proxy in
        ZStack {
          Color.MeetPR.bgBase
          // `radial-gradient(90% 44% at 50% 0%, …)` is an *ellipse*: 90% of the
          // width across, 44% of the height down. A circle of the larger radius
          // over-lights narrow screens (an iPhone SE would get 337pt of glow
          // where the CSS asks for 293pt), so draw a unit circle and stretch it
          // onto the two axes instead.
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
    .hideNavigationBar()
  }
}

/// One-off geometry from the 4a mockup that has no spacing-scale equivalent
/// (`docs/design/login-v3/4a-login-light.html`). Kept named so nobody reads
/// these 44s as the 44pt minimum hit target — they are hero geometry.
private enum Metrics {
  /// `margin-top:44` on the hero column.
  static let heroTopInset: CGFloat = 44
  /// The 44×3 gold rule under the headline.
  static let goldRuleWidth: CGFloat = 44
  /// `height:54` on the login CTA.
  static let ctaHeight: CGFloat = 54
  /// See the call site: 42.24pt target line box − Archivo's 47.8726pt natural
  /// line height at 44pt.
  static let headlineLineSpacing: CGFloat = -5.6326
}
