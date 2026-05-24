import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterRow: View {
  let row: StudentRosterRowModel

  var body: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.base) {
      avatar

      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        HStack(alignment: .firstTextBaseline) {
          Text(row.student.displayName)
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .lineLimit(1)

          Spacer(minLength: MeetPRSpacing.sm)

          if row.needsAttention {
            StatusBadge(status: .live, title: "待关注")
          }
        }

        Text(row.completionText)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)

        HStack(spacing: MeetPRSpacing.sm) {
          Text(row.statusText)
          Text("·")
          Text(lastActiveText)
        }
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
    .padding(.vertical, MeetPRSpacing.xs)
    .accessibilityElement(children: .combine)
  }

  private var avatar: some View {
    ZStack {
      Circle()
        .fill(Color.MeetPR.surface3)
      Text(String(row.student.displayName.prefix(1)))
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
    }
    .frame(width: 44, height: 44)
  }

  private var lastActiveText: String {
    guard let lastActiveAt = row.lastActiveAt else {
      return "暂无训练记录"
    }
    return "上次活跃 \(CoachStudentFormatting.relativeText(lastActiveAt))"
  }
}
