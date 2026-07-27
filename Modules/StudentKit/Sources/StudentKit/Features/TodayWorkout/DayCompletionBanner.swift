import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DayCompletionBanner: View {
  let totalSets: Int
  let onShowReview: () -> Void

  var body: some View {
    Button(action: onShowReview) {
      HStack(spacing: MeetPRSpacing.point10) {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(Color.MeetPR.success)
        Text("今日训练完成 · \(totalSets) 组")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        Text("查看回顾")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Image(systemName: "chevron.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.successRGB.opacity(0.14))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.successRGB.opacity(0.4), lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("今日训练完成，共 \(totalSets) 组，点按查看训练回顾")
  }
}
