import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TrainingMonthDay: View {
  let day: TrainingCalendarDay
  let state: MeetPRDayChip.DayState
  let dayNumber: Int
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      Text(dayNumber.formatted())
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
        .foregroundStyle(numberColor)
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.size46)
        .background(cellBackground)
        .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
        .overlay {
          if day.isToday {
            RoundedRectangle(cornerRadius: MeetPRRadius.inset)
              .stroke(Color.MeetPR.gold500, lineWidth: MeetPRSpacing.point1AndHalf)
          }
        }
        .overlay(alignment: .topTrailing) {
          if let dotColor {
            Circle()
              .fill(dotColor)
              .frame(width: MeetPRSpacing.point5, height: MeetPRSpacing.point5)
              .padding(MeetPRSpacing.point5)
          }
        }
    }
    .buttonStyle(.plain)
  }

  // A plan can materialize rest days as exercise-less plan-day rows, so
  // "has training" means the day actually carries exercises.
  private var hasTraining: Bool { !(day.planDay?.exercises.isEmpty ?? true) }

  // David 2026-07-28: the mockup's color-only distinction is too subtle —
  // training days keep the raised card and primary number (future included),
  // rest days flatten to no card with a dim number.
  private var cellBackground: Color {
    if day.isToday { return Color.MeetPR.surfaceElevated }
    return hasTraining ? Color.MeetPR.surfaceCard : Color.clear
  }

  private var numberColor: Color {
    hasTraining ? Color.MeetPR.textPrimary : Color.MeetPR.textDim
  }

  private var dotColor: Color? {
    switch state {
    case .done:
      Color.MeetPR.success
    case .today:
      Color.MeetPR.gold500
    case .missed:
      Color.MeetPR.danger
    case .rest, .future:
      nil
    }
  }
}
