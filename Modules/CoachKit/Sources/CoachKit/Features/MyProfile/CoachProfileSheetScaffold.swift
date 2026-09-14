import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CoachProfileSheetScaffold<Content: View>: View {
  let title: String
  let subtitle: String
  @ViewBuilder let content: () -> Content
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      HStack(spacing: MeetPRSpacing.space3) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "chevron.left")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
            .meetPRCardSurface(.card)
            .clipShape(.circle)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(CoachMyProfileStrings.cancel)
        .accessibilityIdentifier("coach.profile.sheet.back")

        VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
          Text(title)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(subtitle)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
        Spacer()
      }
      .padding(.horizontal, MeetPRSpacing.point18)
      .padding(.top, MeetPRSpacing.space1)
      .padding(.bottom, MeetPRSpacing.point14)

      Rectangle()
        .fill(Color.MeetPR.borderDefault)
        .frame(height: MeetPRSpacing.point1)

      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
          content()
        }
        .padding(.horizontal, MeetPRSpacing.point18)
        .padding(.top, MeetPRSpacing.space4)
        .padding(.bottom, MeetPRSpacing.point26)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
  }
}
