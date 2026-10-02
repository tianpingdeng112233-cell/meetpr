import CoreModels
import DesignSystem
import SwiftUI

struct TrainingWeekStrip: View {
  let days: [StudentPlanDay]
  @Binding var selectedDayID: UUID?

  var body: some View {
    let page = TrainingSequenceLayout.page(days: days, selectedDayID: selectedDayID)
    if let week = page.visibleWeek {
      VStack(spacing: MeetPRSpacing.space3) {
        HStack(spacing: MeetPRSpacing.space2) {
          TrainingWeekArrow(
            systemImage: "chevron.left", label: .trainingWeekPrevious,
            selection: page.previousWeekSelection, onSelect: select
          )
          TrainingWeekHeading(week: week)
            .frame(maxWidth: .infinity)
          TrainingWeekArrow(
            systemImage: "chevron.right", label: .trainingWeekNext,
            selection: page.nextWeekSelection, onSelect: select
          )
        }

        ViewThatFits(in: .horizontal) {
          TrainingWeekDays(days: week.days, onSelect: select)
          ScrollView(.horizontal) {
            TrainingWeekDays(days: week.days, onSelect: select)
          }
          .scrollIndicators(.hidden)
        }

        if page.showsWeekIndicators {
          TrainingWeekIndicators(page: page)
        }
      }
      .padding(.vertical, MeetPRSpacing.space2)
      .contentShape(.rect)
      .simultaneousGesture(
        DragGesture(minimumDistance: MeetPRSpacing.point30)
          .onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            let destination =
              value.translation.width < 0
              ? page.nextWeekSelection : page.previousWeekSelection
            if let destination { select(destination) }
          }
      )
    }
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
        .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
        .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(selection == nil)
    .accessibilityLabel(StudentStrings.localized(label))
  }
}

private struct TrainingWeekHeading: View {
  let week: TrainingSequenceWeek

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: MeetPRSpacing.space2) {
        Text("W\(week.weekNumber)").font(
          .MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .bold))
        TrainingWeekStatus(state: week.state)
        Text("\(week.completedCount) / \(week.days.count)").font(
          .MeetPR.mono(size: MeetPRFontMetrics.size12))
      }
      VStack(spacing: MeetPRSpacing.space1) {
        HStack(spacing: MeetPRSpacing.space2) {
          Text("W\(week.weekNumber)").font(
            .MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .bold))
          Text("\(week.completedCount) / \(week.days.count)").font(
            .MeetPR.mono(size: MeetPRFontMetrics.size12))
        }
        TrainingWeekStatus(state: week.state)
      }
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
  }
}

private struct TrainingWeekStatus: View {
  let state: TrainingSequenceDayState

  var body: some View {
    Text(StudentStrings.localized(label))
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      .foregroundStyle(state == .current ? Color.MeetPR.goldText : Color.MeetPR.textSecondary)
      .padding(.horizontal, MeetPRSpacing.space2)
      .padding(.vertical, MeetPRSpacing.space1)
      .background(
        state == .current ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.bgStack,
        in: .capsule
      )
      .fixedSize(horizontal: false, vertical: true)
  }

  private var label: StudentStrings.Key {
    switch state {
    case .current: .trainingWeekCurrent
    case .completed: .trainingWeekCompleted
    case .upcoming: .trainingWeekUpcoming
    }
  }
}

private struct TrainingWeekDays: View {
  let days: [TrainingSequenceDay]
  let onSelect: (UUID) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.space1) {
      ForEach(days) { item in
        TrainingWeekDayCell(item: item) { onSelect(item.id) }
      }
    }
  }
}

private struct TrainingWeekDayCell: View {
  let item: TrainingSequenceDay
  let onSelect: () -> Void
  @ScaledMetric(relativeTo: .caption) private var minimumWidth = MeetPRSpacing.minimumHitTarget

  var body: some View {
    Button(action: onSelect) {
      VStack(spacing: MeetPRSpacing.space2) {
        Image(systemName: item.state == .completed ? "checkmark.circle.fill" : "circle")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size17))
          .foregroundStyle(statusColor)
        Text("D\(item.dayNumber)")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(dateLabel)
          .font(
            .MeetPR.mono(
              size: MeetPRFontMetrics.size11,
              weight: item.state == .current ? .bold : .regular
            )
          )
          .foregroundStyle(item.state == .current ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, MeetPRSpacing.space1)
      .padding(.vertical, MeetPRSpacing.space3)
      .frame(minWidth: minimumWidth, maxWidth: .infinity)
      .background(
        item.state == .current ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.surfaceCard
      )
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .strokeBorder(
            item.isSelected ? Color.MeetPR.textPrimary : .clear,
            lineWidth: MeetPRSpacing.point2
          )
      }
      .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
    .accessibilityValue(
      item.state == .current ? StudentStrings.localized(.trainingWeekCurrentDay) : ""
    )
    .accessibilityIdentifier("training.day.\(item.id)")
  }

  private var statusColor: Color {
    switch item.state {
    case .completed: Color.MeetPR.success
    case .current: Color.MeetPR.goldText
    case .upcoming: Color.MeetPR.textDim
    }
  }

  private var dateLabel: String {
    var style = Date.FormatStyle().weekday(.abbreviated).month(.defaultDigits).day()
    style.timeZone = PlanCalendarDayIdentity.utcCalendar.timeZone
    return item.day.scheduledDate.formatted(style)
  }
}

private struct TrainingWeekIndicators: View {
  let page: TrainingSequencePage

  var body: some View {
    HStack(spacing: MeetPRSpacing.space1) {
      ForEach(page.weeks) { week in
        let isVisible = week.id == page.visibleWeek?.id
        Capsule()
          .fill(
            isVisible
              ? Color.MeetPR.textPrimary
              : week.id == page.currentWeekNumber
                ? Color.MeetPR.goldText : Color.MeetPR.borderStrong
          )
          .frame(
            width: isVisible ? MeetPRSpacing.space4 : MeetPRSpacing.point6,
            height: MeetPRSpacing.point6
          )
      }
    }
    .accessibilityHidden(true)
  }
}
