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
                  DashboardLiftSlot(
                    isFilled: cell.families.contains(family),
                    isInProgress: cell.isInProgress
                  )
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
    let status = cell.isInProgress ? "，进行中" : ""
    return "周\(cell.weekday)，\(lifts.isEmpty ? "无训练安排" : lifts)\(status)"
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
        DashboardLiftSlot(isFilled: true, isInProgress: false)
        Text("该日有")
      }
      HStack(spacing: 4) {
        DashboardLiftSlot(isFilled: false, isInProgress: false)
        Text("该日无")
      }
      HStack(spacing: 4) {
        DashboardLiftSlot(isFilled: true, isInProgress: true)
        Text("进行中")
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
  let isInProgress: Bool

  var body: some View {
    Circle()
      .fill(fill)
      .frame(width: 6, height: 6)
      .overlay {
        if !isFilled {
          Circle()
            .stroke(Color.MeetPR.goldRGB.opacity(0.5), lineWidth: 1)
        }
      }
      .accessibilityHidden(true)
  }

  private var fill: Color {
    guard isFilled else { return Color.MeetPR.bgBase.opacity(0) }
    return isInProgress ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardRestDayCard: View {
  let isToday: Bool
  let preview: DashboardRestDayPreview?

  var body: some View {
    if isToday {
      recoveryCard
    } else {
      // Scene 06 covers today's rest slot only; other days keep the original
      // compact card so non-slot areas stay untouched.
      Text("休息日 · 无训练安排")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textMuted)
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: 16))
    }
  }

  private var recoveryCard: some View {
    VStack(spacing: 9) {
      Image(systemName: "moon")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size34, weight: .regular))
        .foregroundStyle(Color.MeetPR.gold500)

      Text("恢复也是计划的一部分")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)

      Text(restCopy)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textMuted)
        .multilineTextAlignment(.center)
        .lineSpacing(3)

      if isToday, let preview {
        HStack(spacing: 11) {
          // Scene 06 preview row uses a barbell glyph, not a calendar.
          Image(systemName: "dumbbell")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .semibold))
            .foregroundStyle(Color.MeetPR.gold500)
            .frame(width: 34, height: 34)
            .background(Color.MeetPR.surfaceRaised)
            .clipShape(.rect(cornerRadius: 10))

          VStack(alignment: .leading, spacing: 1) {
            Text(preview.title)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Text(
              "\(preview.exerciseCount) 个动作 · \(preview.setCount) 组 · "
                + "约 \(preview.estimatedMinutes) 分钟"
            )
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textMuted)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size13, weight: .bold))
            .foregroundStyle(Color.MeetPR.textGhost)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.MeetPR.bgInset)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.top, 5)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 16))
    // Design source:
    // docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html
    // scene 06, rest-day dashed slot.
  }

  private var restCopy: String {
    let nextTraining = preview?.farewellText ?? "下次训练见。"
    return "肌肉在休息时生长。睡够、吃够蛋白质，\(nextTraining)"
  }
}

extension LiftFamily {
  fileprivate static let dashboardOrder: [LiftFamily] = [.squat, .bench, .deadlift]
}
