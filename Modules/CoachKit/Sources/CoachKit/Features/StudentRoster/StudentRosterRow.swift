import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterRow: View {
  let row: StudentRosterRowModel

  var body: some View {
    Card(accessibilityLabel: row.student.displayName) {
      HStack(alignment: .center, spacing: MeetPRSpacing.base) {
        InitialAvatar(row.student.displayName)

        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
            Text(row.student.displayName)
              .font(Font.MeetPR.headline)
              .foregroundStyle(Color.MeetPR.fgPrimary)
              .lineLimit(1)

            Spacer(minLength: MeetPRSpacing.sm)

            StatusBadge(status: statusBadge.status, title: statusBadge.title)
          }

          Text(row.completionText)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .lineLimit(1)

          Text(lastActiveText)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var statusBadge: (status: StatusBadge.Status, title: String) {
    if row.needsAttention {
      return (.live, "待关注")
    }

    switch row.student.status {
    case .active:
      if row.plannedTrainingDays == 0 {
        return (.pending, "暂无计划")
      }
      if row.completedTrainingDays >= row.plannedTrainingDays {
        return (.ready, "本周 \(row.completedTrainingDays)/\(row.plannedTrainingDays)")
      }
      return (.pending, "本周 \(row.completedTrainingDays)/\(row.plannedTrainingDays)")
    case .inEvaluation:
      return (.pending, row.statusText)
    case .abnormal:
      return (.overdue, row.statusText)
    }
  }

  private var lastActiveText: String {
    guard let lastActiveAt = row.lastActiveAt else {
      return "暂无训练记录"
    }
    return "上次活跃 \(CoachStudentFormatting.relativeText(lastActiveAt))"
  }
}
