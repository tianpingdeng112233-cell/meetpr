import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DayCompletionBanner: View {
  let totalSets: Int
  let onShowReview: () -> Void

  var body: some View {
    Button(action: onShowReview) {
      HStack(spacing: 10) {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(Color.MeetPR.green)
        Text("今日训练完成 · \(totalSets) 组")
          .font(.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
        Text("查看回顾")
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      .padding()
      .background(Color.MeetPR.green.opacity(0.14))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.green.opacity(0.4), lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("今日训练完成，共 \(totalSets) 组，点按查看训练回顾")
  }
}
