import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// Coach "我的" tab on the audited v3 light palette.
///
/// The profile intentionally presents only backend-backed values and actions.
/// Unsupported prototype concepts (avatar editing, coach title, aggregate
/// statistics, exercise library, and reminder rules) are not rendered.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachMyProfileView: View {
  @Bindable private var viewModel: CoachMyProfileViewModel
  private let inviteCodes: any InviteCodeRepository
  private let privacyPolicyURL: URL?
  @State private var codesViewModel: InviteCodesViewModel
  @State private var presentedOverlay: CoachProfileOverlay?
  @State private var isInviteCodesPresented = false
  @State private var toastMessage: String?
  @State private var toastTask: Task<Void, Never>?

  init(
    viewModel: CoachMyProfileViewModel,
    inviteCodes: any InviteCodeRepository,
    privacyPolicyURL: URL? = nil
  ) {
    self.viewModel = viewModel
    self.inviteCodes = inviteCodes
    self.privacyPolicyURL = privacyPolicyURL
    self._codesViewModel = State(initialValue: InviteCodesViewModel(repository: inviteCodes))
  }

  @ViewBuilder
  var body: some View {
    #if os(iOS)
      profileContent
        .fullScreenCover(item: $presentedOverlay) { overlay in
          overlayContent(overlay)
            .presentationBackground(
              overlay == .logout ? Color.clear : Color.MeetPR.bgBase
            )
        }
    #else
      profileContent
        .sheet(item: $presentedOverlay) { overlay in
          overlayContent(overlay)
        }
    #endif
  }

  private var profileContent: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
            Text(CoachMyProfileStrings.title)
              .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
              .foregroundStyle(Color.MeetPR.textPrimary)

            nameCard
            inviteCard
            generalSection
            logoutButton
          }
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
          .padding(.top, MeetPRSpacing.point6)
          .padding(.bottom, MeetPRSpacing.point28)
        }
        .scrollIndicators(.hidden)
        .refreshable { await codesViewModel.reload() }

        if let toastMessage {
          Text(toastMessage)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.surfaceCard)
            .multilineTextAlignment(.center)
            .padding(.horizontal, MeetPRSpacing.point18)
            .padding(.vertical, MeetPRSpacing.point11)
            .background(Color.MeetPR.textPrimary)
            .clipShape(.rect(cornerRadius: MeetPRRadius.control))
            .padding(.horizontal, MeetPRSpacing.point28)
            .padding(.bottom, MeetPRSpacing.space5)
            .transition(.opacity)
            .accessibilityIdentifier("coach.profile.toast")
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(isPresented: $isInviteCodesPresented) {
        InviteCodesView(repository: inviteCodes)
      }
    }
    .task { await codesViewModel.loadIfNeeded() }
    .onDisappear {
      toastTask?.cancel()
      toastTask = nil
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
extension CoachMyProfileView {
  private var nameCard: some View {
    Text(viewModel.displayName)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .bold))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.space4)
      .meetPRCardSurface(.card)
      .accessibilityIdentifier("coach.profile.displayName")
  }

  private var inviteCard: some View {
    ZStack(alignment: .topTrailing) {
      Button {
        isInviteCodesPresented = true
      } label: {
        inviteCardContent
      }
      .buttonStyle(PressScaleButtonStyle(scale: 0.98))
      .accessibilityIdentifier("coach.profile.inviteCard")

      if let code = codesViewModel.activePersonalCode {
        Button(CoachMyProfileStrings.copy) {
          copy(code)
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .padding(.horizontal, MeetPRSpacing.point14)
        .padding(.vertical, MeetPRSpacing.point6)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.inset)
            .stroke(Color.MeetPR.borderStrong, lineWidth: MeetPRSpacing.point1)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
        .padding(MeetPRSpacing.space4)
        .accessibilityIdentifier("coach.profile.copyInvite")
      }
    }
  }

  private var inviteCardContent: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      HStack {
        Text(CoachMyProfileStrings.permanentInvite)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.gold500)
        Spacer()
        if codesViewModel.activePersonalCode != nil {
          Color.clear
            .frame(width: MeetPRSpacing.point56, height: MeetPRSpacing.point30)
        }
      }

      if let code = codesViewModel.activePersonalCode {
        Text(code.code)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size26, weight: .bold))
          .tracking(MeetPRFontMetrics.size26 * 0.14)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .minimumScaleFactor(0.7)
          .lineLimit(1)
          .padding(.top, MeetPRSpacing.space2)

        Text(CoachMyProfileStrings.inviteUsage(code.usedCount))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.top, MeetPRSpacing.space2)
      } else {
        Text(inviteSubtitle)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.top, MeetPRSpacing.space2)
      }
    }
    .padding(MeetPRSpacing.space4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .meetPRCardSurface(.card)
    .contentShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private var inviteSubtitle: String {
    switch codesViewModel.state {
    case .idle, .loading: CoachMyProfileStrings.inviteLoading
    case .failed: CoachMyProfileStrings.inviteFailed
    case .loaded: CoachMyProfileStrings.inviteEmpty
    }
  }

  private var generalSection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Text(CoachMyProfileStrings.general)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)

      VStack(spacing: MeetPRSpacing.zero) {
        actionRow(
          title: CoachMyProfileStrings.help,
          accessibilityIdentifier: "coach.profile.help"
        ) {
          presentedOverlay = .help
        }
        divider
        actionRow(
          title: CoachMyProfileStrings.privacyAndTerms,
          accessibilityIdentifier: "coach.profile.privacyTerms"
        ) {
          presentedOverlay = .privacyAndTerms
        }
        divider
        HStack {
          Text(CoachMyProfileStrings.appVersion)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
          Text(CoachMyProfileStrings.appVersionValue(viewModel.appVersion))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
        .padding(.horizontal, MeetPRSpacing.space4)
        .padding(.vertical, MeetPRSpacing.point14)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("coach.profile.appVersion")
      }
      .meetPRCardSurface(.card)
    }
  }

  private var logoutButton: some View {
    Button {
      presentedOverlay = .logout
    } label: {
      Text(CoachMyProfileStrings.logout)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.danger)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.point15)
        .overlay {
          Capsule()
            .stroke(Color.MeetPR.danger.opacity(0.35), lineWidth: MeetPRSpacing.point1)
        }
    }
    .buttonStyle(PressScaleButtonStyle(scale: 0.98))
    .disabled(viewModel.isLoggingOut)
    .accessibilityIdentifier("coach.profile.logout")
  }

  private func actionRow(
    title: String,
    accessibilityIdentifier: String,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        Image(systemName: "chevron.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textDisabled)
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.vertical, MeetPRSpacing.point14)
      .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle(scale: 0.98))
    .accessibilityIdentifier(accessibilityIdentifier)
  }

  private var divider: some View {
    Rectangle()
      .fill(Color.MeetPR.borderHairline)
      .frame(height: MeetPRSpacing.point1)
  }

  @ViewBuilder
  private func overlayContent(_ overlay: CoachProfileOverlay) -> some View {
    switch overlay {
    case .help:
      CoachHelpFeedbackSheet()
    case .privacyAndTerms:
      CoachPrivacyTermsSheet(privacyPolicyURL: privacyPolicyURL)
    case .logout:
      CoachLogoutConfirmationView(
        isLoggingOut: viewModel.isLoggingOut,
        onCancel: { presentedOverlay = nil },
        onLogout: {
          Task {
            await viewModel.logout()
            presentedOverlay = nil
          }
        }
      )
    }
  }

  private func copy(_ code: InviteCode) {
    #if os(iOS)
      UIPasteboard.general.string = code.code
    #elseif os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(code.code, forType: .string)
    #endif
    codesViewModel.markCopied(code)
    showToast(CoachMyProfileStrings.copied)
  }

  private func showToast(_ message: String) {
    toastTask?.cancel()
    withAnimation(MeetPRMotion.press) {
      toastMessage = message
    }
    toastTask = Task {
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      withAnimation(MeetPRMotion.press) {
        toastMessage = nil
      }
    }
  }

}

private enum CoachProfileOverlay: String, Identifiable {
  case help
  case privacyAndTerms
  case logout

  var id: String { rawValue }
}
