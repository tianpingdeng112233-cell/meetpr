import DesignSystem
import Foundation
import Networking
import Observation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AnalyticsPrivacyNotice: View {
  var buildTrack: MeetPRBuildTrack = BuildConfig.buildTrack
  var defaults: UserDefaults = .standard
  let onConfirm: () -> Void

  @State private var consent = LegalConsentState()
  @State private var titleHeight: CGFloat = 0
  @State private var bodyHeight: CGFloat = 0
  @State private var footerHeight: CGFloat = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(AppShellStrings.analyticsPrivacyTitle)
        .font(.title2.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          titleHeight = $0
        }
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if consent.hasDeclined {
            Text(AppShellStrings.consentRequired)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("legal.required")
          } else {
            Text(AppShellStrings.legalConsentBody)
              .fixedSize(horizontal: false, vertical: true)
            Link(AppShellStrings.userAgreement, destination: LegalDocuments.termsURL)
            Link(AppShellStrings.privacyPolicy, destination: LegalDocuments.privacyPolicyURL)
            Text(AppShellStrings.analyticsPrivacyBody(for: buildTrack))
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .font(.body)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          bodyHeight = $0
        }
      }
      .frame(maxHeight: bodyHeight > 0 ? bodyHeight : nil)
      VStack(alignment: .leading, spacing: 20) {
        if consent.hasDeclined {
          Button(AppShellStrings.reviewConsent) { consent.hasDeclined = false }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("legal.review")
        } else {
          Button(AppShellStrings.agreeAndContinue) {
            defaults.set(LegalDocuments.version, forKey: LegalDocuments.acceptedVersionKey)
            onConfirm()
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("legal.agree")
          Button(AppShellStrings.declineConsent) { consent.hasDeclined = true }
            .accessibilityIdentifier("legal.decline")
        }
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
      .fixedSize(horizontal: false, vertical: true)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        footerHeight = $0
      }
    }
    .padding(24)
    .background(Color.MeetPR.bg)
    .interactiveDismissDisabled()
    // Preserve the existing 24pt insets and 20pt gaps; the sheet caps this ideal height
    // to the available screen, leaving only the body scrollable on smaller screens.
    .presentationDetents([
      bodyHeight > 0 ? .height(titleHeight + bodyHeight + footerHeight + 88) : .large
    ])
  }

  static let privacyPolicyURL = LegalDocuments.privacyPolicyURL
}

@MainActor
@Observable
private final class LegalConsentState {
  var hasDeclined = false
}
