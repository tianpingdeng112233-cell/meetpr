import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DayCompletionBanner: View {
  let totalSets: Int

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(Color.MeetPR.green)
      Text("今日训练完成 · \(totalSets) 组")
        .font(.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
    }
    .padding()
    .background(Color.MeetPR.green.opacity(0.14))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.green.opacity(0.4), lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
  }
}
