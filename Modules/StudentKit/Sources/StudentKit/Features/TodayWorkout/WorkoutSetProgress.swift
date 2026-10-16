import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct WorkoutSetProgress: View {
  let drafts: [TodayWorkoutSetRowDraft]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("已完成 \(completedCount)/\(drafts.count) 组")
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
        Text(nextSetText)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .lineLimit(1)
      }
      .font(.system(size: 12, weight: .medium, design: .monospaced))

      ProgressView(value: progress)
        .tint(Color.MeetPR.fgPrimary)
    }
    .accessibilityElement(children: .combine)
  }

  private var completedCount: Int {
    drafts.count(where: \.completed)
  }

  private var progress: Double {
    guard !drafts.isEmpty else { return 0 }
    return Double(completedCount) / Double(drafts.count)
  }

  private var nextSetText: String {
    guard let next = drafts.first(where: { !$0.completed }) else { return "全部完成" }
    return "下一组：\(next.exerciseName)"
  }
}
