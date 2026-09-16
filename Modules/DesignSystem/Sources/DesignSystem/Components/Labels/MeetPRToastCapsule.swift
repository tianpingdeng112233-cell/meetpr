import SwiftUI

@MainActor
public struct MeetPRToastCapsule: View {
  private let emphasizedText: String
  private let trailingText: String

  public init(emphasizedText: String, trailingText: String) {
    self.emphasizedText = emphasizedText
    self.trailingText = trailingText
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Image(systemName: "checkmark")
        .font(.system(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: MeetPRSpacing.point22, height: MeetPRSpacing.point22)
        .background(Color.MeetPR.gold500, in: .circle)

      HStack(spacing: MeetPRSpacing.space1) {
        Text(emphasizedText)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.gold300)
        Text(trailingText)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
          .foregroundStyle(.white)
      }
    }
    .padding(.leading, MeetPRSpacing.point14)
    .padding(.trailing, MeetPRSpacing.point18)
    .frame(minHeight: MeetPRSpacing.point40)
    .background(Color.MeetPR.surfaceFocus, in: .capsule)
    .shadow(color: Color.black.opacity(0.22), radius: MeetPRSpacing.space5, y: MeetPRSpacing.space2)
    .accessibilityElement(children: .combine)
  }
}
