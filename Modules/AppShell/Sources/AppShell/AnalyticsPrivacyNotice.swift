import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AnalyticsPrivacyNotice: View {
  let onConfirm: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(AppShellStrings.analyticsPrivacyTitle)
        .font(.title2.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text(AppShellStrings.analyticsPrivacyBody)
        .font(.body)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Link(AppShellStrings.privacyPolicy, destination: Self.privacyPolicyURL)
      Button(AppShellStrings.acknowledge, action: onConfirm)
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(24)
    .background(Color.MeetPR.bg)
    .presentationDetents([.medium])
  }

  static let privacyPolicyURL =
    URL(string: "https://meetpr.app/privacy") ?? URL(fileURLWithPath: "/")
}
