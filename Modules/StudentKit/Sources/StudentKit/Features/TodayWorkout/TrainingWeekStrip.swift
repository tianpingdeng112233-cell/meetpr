import CoreModels
import DesignSystem
import SwiftUI

struct TrainingWeekStrip: View {
  let days: [StudentPlanDay]
  @Binding var selectedDayID: UUID?
  var today: Date = WorkoutDatePolicy.gymDayToday()

  var body: some View {
    let page = TrainingSequenceLayout.page(days: days, selectedDayID: selectedDayID)
    if let week = page.visibleWeek {
      HStack(spacing: MeetPRSpacing.zero) {
        TrainingWeekArrow(
          systemImage: "chevron.left", label: .trainingWeekPrevious,
          selection: page.previousWeekSelection, onSelect: select)
        TrainingWeekCalendarRow(
          cells: week.calendarCells, today: today, onSelect: select,
          onSwipe: { forward in turnPage(page, forward: forward) })
        TrainingWeekArrow(
          systemImage: "chevron.right", label: .trainingWeekNext,
          selection: page.nextWeekSelection, onSelect: select)
      }
      .padding(.vertical, MeetPRSpacing.space2)
    }
  }

  private func turnPage(_ page: TrainingSequencePage, forward: Bool) {
    let destination = forward ? page.nextWeekSelection : page.previousWeekSelection
    if let destination { select(destination) }
  }

  private func select(_ dayID: UUID) {
    selectedDayID = dayID
  }
}

private struct TrainingWeekArrow: View {
  let systemImage: String
  let label: StudentStrings.Key
  let selection: UUID?
  let onSelect: (UUID) -> Void

  var body: some View {
    Button {
      if let selection { onSelect(selection) }
    } label: {
      Image(systemName: systemImage)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .bold))
        .foregroundStyle(selection == nil ? Color.MeetPR.textDim : Color.MeetPR.textPrimary)
        .frame(width: MeetPRSpacing.point28, height: MeetPRSpacing.point64)
        .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(selection == nil)
    .accessibilityLabel(StudentStrings.localized(label))
  }
}

struct TrainingWeekHeading: View {
  let week: TrainingSequenceWeek
  let today: Date
  @Environment(\.locale) private var locale

  var body: some View {
    let status = TrainingWeekStatusPresentation(
      state: week.state,
      daysBehind: TrainingSequenceLayout.daysBehind(days: week.days.map(\.day), today: today),
      locale: locale)
    TrainingWeekHeaderLayout {
      Text("W\(week.weekNumber)")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .bold))
      Text(status.text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(
          week.state == .current ? Color.MeetPR.goldText : Color.MeetPR.textSecondary
        )
        .padding(.horizontal, MeetPRSpacing.space2)
        .padding(.vertical, MeetPRSpacing.space1)
        .background(
          week.state == .current ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.bgStack,
          in: .capsule
        )
        .accessibilityLabel(status.accessibilityLabel)
      Text("\(week.completedCount) / \(week.days.count)")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .lineLimit(1)
    .minimumScaleFactor(0.3)
  }
}
