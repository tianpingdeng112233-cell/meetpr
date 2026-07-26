import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardWeekCalendar: View {
  let cells: [DashboardWeekCalendarCell]
  let onSelect: (Date) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("本周")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer(minLength: 8)
        DashboardWeekCalendarLegend()
      }

      HStack(spacing: 6) {
        ForEach(cells) { cell in
          Button {
            onSelect(cell.date)
          } label: {
            VStack(spacing: 5) {
              Text(cell.weekday)
                .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
                .foregroundStyle(
                  cell.isSelected
                    ? Color.MeetPR.textPrimary
                    : Color.MeetPR.textMuted
                )

              HStack(spacing: 3) {
                ForEach(LiftFamily.dashboardOrder, id: \.self) { family in
                  DashboardLiftSlot(isFilled: cell.families.contains(family))
                }
              }
              .frame(height: 7)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(
              cell.isSelected
                ? Color.MeetPR.goldRGB.opacity(0.12)
                : Color.MeetPR.surfaceCard
            )
            .clipShape(
              .rect(cornerRadius: cell.isSelected ? 999 : 12)
            )
            .overlay {
              if cell.isSelected {
                RoundedRectangle(cornerRadius: 999)
                  .stroke(Color.MeetPR.gold500, lineWidth: 1.5)
              }
            }
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(accessibilityLabel(for: cell))
        }
      }
    }
  }

  private func accessibilityLabel(for cell: DashboardWeekCalendarCell) -> String {
    let lifts = cell.families.map(\.studentDisplayName).joined(separator: "、")
    return "周\(cell.weekday)，\(lifts.isEmpty ? "无训练安排" : lifts)"
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardWeekCalendarLegend: View {
  var body: some View {
    HStack(spacing: 7) {
      Text("深蹲·卧推·硬拉")
        .foregroundStyle(Color.MeetPR.textDim)
      Rectangle()
        .fill(Color.MeetPR.borderStrong)
        .frame(width: 1, height: 9)
      HStack(spacing: 4) {
        DashboardLiftSlot(isFilled: true)
        Text("该日有")
      }
      HStack(spacing: 4) {
        DashboardLiftSlot(isFilled: false)
        Text("该日无")
      }
    }
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
    .foregroundStyle(Color.MeetPR.textMuted)
    .lineLimit(1)
    .minimumScaleFactor(0.82)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardLiftSlot: View {
  let isFilled: Bool

  var body: some View {
    Circle()
      .fill(isFilled ? Color.MeetPR.gold500 : Color.MeetPR.bgBase.opacity(0))
      .frame(width: 6, height: 6)
      .overlay {
        if !isFilled {
          Circle()
            .stroke(Color.MeetPR.goldRGB.opacity(0.5), lineWidth: 1)
        }
      }
      .accessibilityHidden(true)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardRestDayCard: View {
  let isToday: Bool
  let nextTrainingDate: Date?

  var body: some View {
    VStack(spacing: 5) {
      Text(isToday ? "今天是休息日" : "休息日 · 无训练安排")
        .font(
          .MeetPR.body(
            size: isToday ? MeetPRFontMetrics.size16 : MeetPRFontMetrics.size14,
            weight: .semibold
          )
        )
        .foregroundStyle(Color.MeetPR.textMuted)

      if isToday, let nextTrainingDate {
        Text("下次训练 \(nextTrainingLabel(nextTrainingDate))")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textFaint)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 16))
  }

  private func nextTrainingLabel(_ date: Date) -> String {
    let offset = DashboardTodayPresentation.mondayOffset(
      for: date,
      calendar: PlanCalendarDayIdentity.utcCalendar
    )
    let monthDay = DashboardTodayPresentation.monthDayText(date)
    return "周\(DashboardTodayPresentation.weekdayLetter(offset)) · \(monthDay)"
  }
}

extension LiftFamily {
  fileprivate static let dashboardOrder: [LiftFamily] = [.squat, .bench, .deadlift]
}
