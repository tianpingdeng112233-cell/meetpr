import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CoachPrivacyTermsSheet: View {
  let privacyPolicyURL: URL?
  @Environment(\.openURL) private var openURL

  var body: some View {
    CoachProfileSheetScaffold(
      title: CoachMyProfileStrings.privacyAndTerms,
      subtitle: CoachMyProfileStrings.privacyAndTermsSubtitle
    ) {
      VStack(spacing: MeetPRSpacing.zero) {
        documentRow(
          title: CoachMyProfileStrings.userAgreement,
          destination: nil
        )
        documentRow(
          title: CoachMyProfileStrings.privacyPolicy,
          destination: privacyPolicyURL
        )
        studentDataRow
      }
      .meetPRCardSurface(.card)

      Text(CoachMyProfileStrings.studentDataDescription)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textTertiary)
        .lineSpacing(MeetPRSpacing.point9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func documentRow(title: String, destination: URL?) -> some View {
    if let destination {
      #if os(iOS)
        Button {
          openURL(destination)
        } label: {
          rowContent(title: title, isEnabled: true)
        }
        .accessibilityIdentifier("coach.profile.privacyPolicy")
      #else
        Link(destination: destination) {
          rowContent(title: title, isEnabled: true)
        }
        .accessibilityIdentifier("coach.profile.privacyPolicy")
      #endif
    } else {
      rowContent(title: title, isEnabled: false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("coach.profile.userAgreement.unavailable")
    }
  }

  private func rowContent(title: String, isEnabled: Bool) -> some View {
    HStack {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(isEnabled ? Color.MeetPR.textPrimary : Color.MeetPR.textDisabled)
      Spacer()
      Text(CoachMyProfileStrings.documentDate)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textDisabled)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .frame(maxWidth: .infinity)
    .contentShape(.rect)
    .overlay(alignment: .top) {
      if title == CoachMyProfileStrings.privacyPolicy {
        Rectangle()
          .fill(Color.MeetPR.borderHairline)
          .frame(height: MeetPRSpacing.point1)
      }
    }
  }

  private var studentDataRow: some View {
    Text(CoachMyProfileStrings.studentDataUsage)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.vertical, MeetPRSpacing.point14)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(Color.MeetPR.borderHairline)
          .frame(height: MeetPRSpacing.point1)
      }
      .accessibilityIdentifier("coach.profile.studentDataUsage")
  }
}
