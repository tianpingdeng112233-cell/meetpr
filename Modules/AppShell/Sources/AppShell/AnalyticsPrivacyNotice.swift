import DesignSystem
import Foundation
import Networking
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AnalyticsPrivacyNotice: View {
  var buildTrack: MeetPRBuildTrack = BuildConfig.buildTrack
  let onConfirm: () -> Void

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
        Text(AppShellStrings.analyticsPrivacyBody(for: buildTrack))
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
        Link(AppShellStrings.privacyPolicy, destination: Self.privacyPolicyURL)
        Button(AppShellStrings.acknowledge, action: onConfirm)
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .fixedSize(horizontal: false, vertical: true)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        footerHeight = $0
      }
    }
    .padding(24)
    .background(Color.MeetPR.bg)
    // Preserve the existing 24pt insets and 20pt gaps; the sheet caps this ideal height
    // to the available screen, leaving only the body scrollable on smaller screens.
    .presentationDetents([
      bodyHeight > 0 ? .height(titleHeight + bodyHeight + footerHeight + 88) : .large
    ])
  }

  static let privacyPolicyURL =
    URL(string: "https://meetpr.app/privacy") ?? URL(fileURLWithPath: "/")
}
