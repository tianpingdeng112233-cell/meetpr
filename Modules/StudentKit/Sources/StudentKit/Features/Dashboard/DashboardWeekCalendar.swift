import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardWeekCalendar: View {
  enum HeaderStyle {
    case progress
    case currentWeek
  }

  let weekNumber: Int
  let cells: [DashboardWeekProgressSegment]
  var headerStyle: HeaderStyle = .progress

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DashboardWeekCalendarHeader(
        style: headerStyle,
        weekNumber: weekNumber,
        completedCount: completedCount,
        totalCount: cells.count
      )

      HStack(spacing: 6) {
        ForEach(cells) { cell in
          VStack(spacing: 5) {
            status(for: cell.state)
            Text("D\(cell.dayNumber)")
              .font(
                .MeetPR.mono(
                  size: MeetPRFontMetrics.size10,
                  weight: cell.state == .current ? .bold : .semibold
                )
              )
              .foregroundStyle(
                cell.state == .current ? Color.MeetPR.textPrimary : Color.MeetPR.textMuted)
            Text(recommendedDate(cell.recommendedDate))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
              .foregroundStyle(
                cell.state == .current ? Color.MeetPR.textSecondary : Color.MeetPR.textMuted
              )
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
          .frame(maxWidth: .infinity, minHeight: 58)
          .background(background(for: cell.state))
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

  private var completedCount: Int {
    cells.filter { $0.state == .done }.count
  }

  private func background(for state: DashboardWeekProgressState) -> Color {
    switch state {
    case .done:
      Color.MeetPR.surfaceCard
    case .current:
      Color.MeetPR.goldRGB.opacity(0.12)
    case .upcoming:
      Color.MeetPR.bgInset
    }
  }

  private func recommendedDate(_ date: Date) -> String {
    let calendar = PlanCalendarDayIdentity.utcCalendar
    let components = calendar.dateComponents([.month, .day, .weekday], from: date)
    let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    let weekdayIndex = (components.weekday ?? 1) - 1
    let weekday = weekdays.indices.contains(weekdayIndex) ? weekdays[weekdayIndex] : ""
    return "\(components.month ?? 0)/\(components.day ?? 0) \(weekday)"
  }

  private func statusText(_ state: DashboardWeekProgressState) -> String {
    switch state {
    case .done: "已完成"
    case .current: "当前"
    case .upcoming: "未轮到"
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardWeekCalendarHeader: View {
  let style: DashboardWeekCalendar.HeaderStyle
  let weekNumber: Int
  let completedCount: Int
  let totalCount: Int

  var body: some View {
    switch style {
    case .progress:
      HStack(spacing: 10) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("本周进度")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
          Text("\(completedCount) / \(totalCount)")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
        }
        .foregroundStyle(Color.MeetPR.textSecondary)

        Spacer()

        WeekRecommendationLabel()
      }
    case .currentWeek:
      HStack(spacing: 8) {
        HStack(spacing: 8) {
          Text("W\(weekNumber)")
            .font(.MeetPR.display(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textPrimary)

          Text("当前周")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.MeetPR.goldText)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.MeetPR.goldRGB.opacity(0.14), in: .capsule)
        }

        Spacer()

        HStack(spacing: 8) {
          Text("\(completedCount) / \(totalCount)")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textMuted)

          Rectangle()
            .fill(Color.MeetPR.borderStrong)
            .frame(width: 1, height: 10)

          WeekRecommendationLabel()
        }
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct WeekRecommendationLabel: View {
  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "calendar")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textDisabled)
      Text("教练推荐日期")
    }
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
    .foregroundStyle(Color.MeetPR.textMuted)
    .lineLimit(1)
    .fixedSize(horizontal: true, vertical: false)
  }
}
