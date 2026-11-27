import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CoachPrivacyTermsSheet: View {
  let privacyPolicyURL: URL?
  let termsURL: URL?

  var body: some View {
    CoachProfileSheetScaffold(
      title: CoachMyProfileStrings.privacyAndTerms,
      subtitle: CoachMyProfileStrings.privacyAndTermsSubtitle
    ) {
      VStack(spacing: MeetPRSpacing.zero) {
        documentRow(
          title: CoachMyProfileStrings.userAgreement,
          destination: termsURL,
          identifier: "coach.profile.userAgreement"
        )
        documentRow(
          title: CoachMyProfileStrings.privacyPolicy,
          destination: privacyPolicyURL,
          identifier: "coach.profile.privacyPolicy"
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
  private func documentRow(title: String, destination: URL?, identifier: String) -> some View {
    if let destination {
      Link(destination: destination) {
        rowContent(title: title, isEnabled: true)
      }
      .accessibilityIdentifier(identifier)
    } else {
      rowContent(title: title, isEnabled: false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
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
