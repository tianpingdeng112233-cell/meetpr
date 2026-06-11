import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningStudentHeaderView: View {
  let student: CoachStudentSummary
  @State private var isExpanded = false

  var body: some View {
    Card(accessibilityLabel: "Selected student") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          Text(student.displayName)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          Text(statusSummary)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .lineLimit(1)

          Spacer()

          Button(isExpanded ? "收起" : "展开") {
            isExpanded.toggle()
          }
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.brandRed)
        }

        if isExpanded {
          VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
            Text("学员 ID：\(student.id.uuidString)")
            Text("状态：\(statusSummary)")
          }
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }

  private var statusSummary: String {
    switch student.status {
    case .inEvaluation(let days, let hours):
      "评估期 \(days) 天 \(hours) 时剩"
    case .active:
      "活跃"
    case .abnormal(let reason):
      PlanningDisplay.abnormalReason(reason)
    }
  }
}
