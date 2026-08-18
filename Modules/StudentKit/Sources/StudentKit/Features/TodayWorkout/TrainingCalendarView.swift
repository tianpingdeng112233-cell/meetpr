import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TrainingCalendarView: View {
  private let days: [StudentPlanDay]

  @Binding private var selectedDayID: UUID?
  @State private var expandedWeeks: Set<Int> = []

  init(
    selectedDayID: Binding<UUID?>,
    days: [StudentPlanDay]
  ) {
    self.days = days
    self._selectedDayID = selectedDayID
  }

  var body: some View {
    sequenceContent(days: days)
      .task(id: daysRevision) {
        normalizeSelection()
      }
  }

  private var daysRevision: String {
    days.map { day in
      "\(day.id.uuidString)-\(day.completedAt?.timeIntervalSince1970 ?? 0)"
    }
    .joined(separator: ":")
  }

  private func normalizeSelection() {
    selectedDayID = TrainingSequenceLayout.initialSelection(
      days: days,
      explicitDayID: selectedDayID
    )
    if let currentWeek = TrainingSequenceLayout.currentWeekNumber(days: days) {
      expandedWeeks.insert(currentWeek)
    }
  }

  private func sequenceContent(days: [StudentPlanDay]) -> some View {
    let weeks = TrainingSequenceLayout.weeksFromCurrent(days: days, selectedDayID: selectedDayID)
    let completedCount = days.filter { $0.completedAt != nil }.count
    let currentWeekNumber = TrainingSequenceLayout.currentWeekNumber(days: days)
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(StudentStrings.localized(.trainingCalendarView001))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer()
        Text(
          StudentStrings.replacing(
            .trainingCalendarView002, values: ["\(completedCount)", "\(days.count)"])
        )
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      }

      ForEach(weeks) { week in
        weekSection(week, isCurrentWeek: week.weekNumber == currentWeekNumber)
      }
    }
  }

  private func weekSection(_ week: TrainingSequenceWeek, isCurrentWeek: Bool) -> some View {
    VStack(spacing: 7) {
      TrainingWeekHeader(
        week: week,
        isCurrentWeek: isCurrentWeek,
        isExpanded: expandedWeeks.contains(week.weekNumber),
        meta: weekMeta(week, isCurrentWeek: isCurrentWeek),
        onToggle: { toggleWeek(week.weekNumber) }
      )

      if expandedWeeks.contains(week.weekNumber) {
        VStack(spacing: 0) {
          ForEach(week.days) { item in
            sequenceRow(item)
          }
        }
        .padding(.horizontal, 13)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: 14))
      }
    }
  }

  private func toggleWeek(_ weekNumber: Int) {
    if expandedWeeks.contains(weekNumber) {
      expandedWeeks.remove(weekNumber)
    } else {
      expandedWeeks.insert(weekNumber)
    }
  }

  private func weekMeta(_ week: TrainingSequenceWeek, isCurrentWeek: Bool) -> String {
    if isCurrentWeek {
      let completedCount = week.days.filter { $0.state == .completed }.count
      return StudentStrings.replacing(
        .trainingCalendarView003, values: ["\(completedCount)", "\(week.days.count)"])
    }
    guard let firstDay = week.days.first else {
      return StudentStrings.localized(.trainingCalendarView004)
    }
    return StudentStrings.replacing(
      .trainingCalendarView005,
      values: [
        "\(week.days.count)", "\(TrainingSequenceText.shortDate(firstDay.day.scheduledDate))",
      ])
  }

  private func sequenceRow(_ item: TrainingSequenceDay) -> some View {
    Button {
      selectedDayID = item.id
    } label: {
      HStack(spacing: 12) {
        Text("D\(item.day.dayOfWeek)")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(item.state == .current ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
          .frame(width: 32, height: 32)
          .background(
            item.state == .current ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.bgInset
          )
          .clipShape(.circle)

        VStack(alignment: .leading, spacing: 3) {
          Text(TrainingSequenceText.dayName(item.day))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(TrainingSequenceText.exerciseSummary(item.day))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textMuted)
          Text(TrainingSequenceText.recommendation(item.day.scheduledDate))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textDim)
        }
        Spacer()
        statusIcon(item.state)
      }
      .padding(.vertical, 10)
      .contentShape(.rect)
      .background(item.isSelected ? Color.MeetPR.goldRGB.opacity(0.08) : Color.clear)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func statusIcon(_ state: TrainingSequenceDayState) -> some View {
    switch state {
    case .completed:
      Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.MeetPR.success)
    case .current:
      Circle().fill(Color.MeetPR.gold500).frame(width: 8, height: 8)
    case .upcoming:
      Circle().stroke(Color.MeetPR.textGhost, lineWidth: 1).frame(width: 8, height: 8)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingWeekHeader: View {
  let week: TrainingSequenceWeek
  let isCurrentWeek: Bool
  let isExpanded: Bool
  let meta: String
  let onToggle: () -> Void

  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: 10) {
        TrainingWeekIdentity(weekNumber: week.weekNumber, isCurrentWeek: isCurrentWeek)

        Text(TrainingSequenceText.weekSummary(week.days))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textMuted)
          .lineLimit(1)

        Spacer()

        Text(meta)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
          .fixedSize(horizontal: true, vertical: false)

        Image(systemName: "chevron.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size10, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textDim)
          .rotationEffect(isExpanded ? .degrees(90) : .zero)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
      .frame(minHeight: 44)
      .background(Color.MeetPR.bgStack)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.borderHairline, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingWeekIdentity: View {
  let weekNumber: Int
  let isCurrentWeek: Bool

  var body: some View {
    HStack(spacing: 10) {
      Text("W\(weekNumber)")
        .font(.MeetPR.display(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)

      if isCurrentWeek {
        Text(StudentStrings.localized(.trainingCalendarView006))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .bold))
          .tracking(0.6)
          .foregroundStyle(Color.MeetPR.goldText)
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(Color.MeetPR.goldRGB.opacity(0.14), in: .capsule)
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct TrainingCurrentWeekSequenceView: View {
  let days: [StudentPlanDay]

  var body: some View {
    let cells = DashboardTodayPresentation.progressSegments(days: days)
    if let weekNumber = TrainingSequenceLayout.currentWeekNumber(days: days), !cells.isEmpty {
      DashboardWeekCalendar(weekNumber: weekNumber, cells: cells, headerStyle: .currentWeek)
    }
  }
}
