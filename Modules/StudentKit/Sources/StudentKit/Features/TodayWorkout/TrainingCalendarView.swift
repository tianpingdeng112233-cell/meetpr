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
    let weeks = TrainingSequenceLayout.makeWeeks(days: days, selectedDayID: selectedDayID)
    let completedCount = days.filter { $0.completedAt != nil }.count
    return VStack(alignment: .leading, spacing: 10) {
      Text("计划汇总")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("已完成 \(completedCount) / \(days.count) 节")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)

      ForEach(weeks) { week in
        weekSection(week)
      }
    }
  }

  private func weekSection(_ week: TrainingSequenceWeek) -> some View {
    VStack(spacing: 0) {
      Button {
        if expandedWeeks.contains(week.weekNumber) {
          expandedWeeks.remove(week.weekNumber)
        } else {
          expandedWeeks.insert(week.weekNumber)
        }
      } label: {
        HStack {
          Text("W\(week.weekNumber)")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.gold500)
          Text("\(week.days.filter { $0.state == .completed }.count)/\(week.days.count) 节")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
          Spacer()
          Image(systemName: expandedWeeks.contains(week.weekNumber) ? "chevron.up" : "chevron.down")
            .foregroundStyle(Color.MeetPR.textDim)
        }
        .frame(minHeight: 46)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if expandedWeeks.contains(week.weekNumber) {
        ForEach(week.days) { item in
          sequenceRow(item)
        }
      }
    }
    .padding(.horizontal, 13)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 14))
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
