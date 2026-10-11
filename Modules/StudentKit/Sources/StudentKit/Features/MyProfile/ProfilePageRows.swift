import DesignSystem
import SwiftUI

struct MyProfileValueRow: View {
  let label: String
  let value: String
  var inline = false

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      if inline {
        StudentMenuTextLayout {
          Text(label)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .fixedSize()
          Text(value)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
          Text(label)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(value)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      Image(systemName: "chevron.right")
        .font(.system(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDim)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .frame(minHeight: MeetPRSpacing.minimumHitTarget + MeetPRSpacing.space3)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

struct MyProfileGroupCard<Content: View>: View {
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(spacing: 0) { content }
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

struct MyProfileDivider: View {
  var body: some View {
    Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: 1)
      .padding(.horizontal, MeetPRSpacing.space4)
  }
}
