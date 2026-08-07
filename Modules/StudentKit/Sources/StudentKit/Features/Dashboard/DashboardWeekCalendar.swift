import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardWeekCalendar: View {
  let weekNumber: Int
  let cells: [DashboardWeekProgressSegment]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("本周进度")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer()
        Text("教练推荐日期")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textDim)
      }

      HStack(spacing: 7) {
        ForEach(cells) { cell in
          VStack(spacing: 5) {
            Text("D\(cell.dayNumber)")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
              .foregroundStyle(
                cell.state == .current ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
            status(for: cell.state)
            Text(shortDate(cell.recommendedDate))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
              .foregroundStyle(Color.MeetPR.textDim)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .frame(maxWidth: .infinity, minHeight: 58)
          .background(
            cell.state == .current ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.surfaceCard
          )
          .clipShape(.rect(cornerRadius: 12))
          .overlay {
            if cell.state == .current {
              RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.gold500, lineWidth: 1.5)
            }
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("第\(weekNumber)周第\(cell.dayNumber)天，\(statusText(cell.state))")
        }
      }
    }
  }

  @ViewBuilder
  private func status(for state: DashboardWeekProgressState) -> some View {
    switch state {
    case .done:
      Image(systemName: "checkmark")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size11, weight: .bold))
        .foregroundStyle(Color.MeetPR.success)
    case .current:
      Circle().fill(Color.MeetPR.gold500).frame(width: 7, height: 7)
    case .upcoming:
      Circle().stroke(Color.MeetPR.textGhost, lineWidth: 1).frame(width: 7, height: 7)
    }
  }

  private func shortDate(_ date: Date) -> String {
    let components = PlanCalendarDayIdentity.utcCalendar.dateComponents([.month, .day], from: date)
    return "\(components.month ?? 0)/\(components.day ?? 0)"
  }

  private func statusText(_ state: DashboardWeekProgressState) -> String {
    switch state {
    case .done: "已完成"
    case .current: "当前"
    case .upcoming: "未轮到"
    }
  }
}
