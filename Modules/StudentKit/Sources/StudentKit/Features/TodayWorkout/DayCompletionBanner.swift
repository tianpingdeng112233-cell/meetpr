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
          .font(.headline)
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        Text("查看回顾")
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.textSecondary)
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      .padding()
      .background(Color.MeetPR.success.opacity(0.14))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.success.opacity(0.4), lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel("今日训练完成，共 \(totalSets) 组，点按查看训练回顾")
  }
}
