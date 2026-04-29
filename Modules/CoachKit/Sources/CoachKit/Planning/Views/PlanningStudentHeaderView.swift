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

          Text(liftsSummary)
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
            Text("训练日：\(PlanningDisplay.compactWeekdays(student.profile.trainingDaysOfWeek))")
            Text("训练环境：\(student.profile.gymTier.rawValue)")
            Text("想增强：\(student.profile.musclesToStrengthen.joined(separator: " / "))")
            Text("伤病：\(student.profile.injuries.joined(separator: " / "))")
            Text("训练年限：\(student.profile.trainingYears) 年")
          }
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }

  private var liftsSummary: String {
    let squat = student.profile.currentSquat1RM
    let bench = student.profile.bench1RM
    let deadlift = student.profile.deadlift1RM
    return "S:\(squat) B:\(bench) D:\(deadlift)"
  }
}
