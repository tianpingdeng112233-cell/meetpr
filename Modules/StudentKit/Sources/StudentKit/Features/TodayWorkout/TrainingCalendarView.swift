import CoreModels
import DesignSystem
import Foundation
import Observation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TrainingCalendarView: View {
  private let studentID: UUID
  private let calendar: Calendar
  private let today: @Sendable () -> Date
  private let planRevision: Int

  @Binding private var selectedDate: Date
  @State private var displayedDate: Date
  @State private var mode: TrainingCalendarMode = .week
  @State private var viewModel: TrainingCalendarViewModel

  init(
    studentID: UUID,
    selectedDate: Binding<Date>,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    calendar: Calendar = .current,
    today: @escaping @Sendable () -> Date = { Date() },
    planRevision: Int = 0
  ) {
    self.studentID = studentID
    var resolvedCalendar = calendar
    resolvedCalendar.firstWeekday = 2
    self.calendar = resolvedCalendar
    self.today = today
    self.planRevision = planRevision
    self._selectedDate = selectedDate
    self._displayedDate = State(
      initialValue: PlanCalendarDayIdentity.deviceDay(
        containing: selectedDate.wrappedValue,
        calendar: resolvedCalendar
      )
    )
    self._viewModel = State(initialValue: TrainingCalendarViewModel(plans: plans, logs: logs))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point13) {
      toolbar
      content
      // The legend lives in `TrainingCalendarLegend`, rendered by the screen
      // so the collapsed state can *remove* it — static text nodes survive
      // accessibility hiding in runtime snapshots, and the legend is the one
      // stateless piece that can safely leave the tree.
    }
    .task(id: planRevision) {
      await viewModel.load(studentID: studentID)
    }
    .onChange(of: selectedDate) { _, newValue in
      displayedDate = newValue
    }
    .onChange(of: mode) { _, _ in
      displayedDate = selectedDate
    }
  }

  private var toolbar: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Button {
        movePeriod(by: -1)
      } label: {
        Text("‹")
          .frame(
            width: MeetPRSpacing.minimumHitTarget,
            height: MeetPRSpacing.minimumHitTarget
          )
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(mode == .week ? "上一周" : "上一月")

      Text(periodTitle)

      Button {
        movePeriod(by: 1)
      } label: {
        Text("›")
          .frame(
            width: MeetPRSpacing.minimumHitTarget,
            height: MeetPRSpacing.minimumHitTarget
          )
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(mode == .week ? "下一周" : "下一月")

      Spacer()

      HStack(spacing: MeetPRSpacing.zero) {
        modeButton(.week, title: "周")
        modeButton(.month, title: "月")
      }
      .background {
        RoundedRectangle(cornerRadius: MeetPRRadius.inset)
          .fill(Color.MeetPR.surfaceCard)
          .frame(height: 23)
      }
    }
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
    .foregroundStyle(Color.MeetPR.textMuted)
  }

  private var periodTitle: String {
    displayedDate.formatted(
      .dateTime.month(.wide).locale(Locale(identifier: "zh_CN"))
    )
  }

  private func modeButton(_ value: TrainingCalendarMode, title: String) -> some View {
    Button {
      mode = value
    } label: {
      ZStack {
        if mode == value {
          RoundedRectangle(cornerRadius: MeetPRSpacing.point6)
            .fill(value == .week ? Color.MeetPR.ctaFill : Color.MeetPR.borderStrong)
            .frame(width: 38, height: 17)
        }

        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(mode == value ? Color.white : Color.MeetPR.textMuted)
      }
      .frame(
        width: MeetPRSpacing.minimumHitTarget,
        height: MeetPRSpacing.minimumHitTarget
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 46)
    case .loaded(let cycleDays, let logs):
      let days = TrainingCalendarLayout.makeDays(
        period: TrainingCalendarPeriod(
          displayedDate: displayedDate,
          selectedDate: selectedDate,
          today: today(),
          mode: mode
        ),
        cycleDays: cycleDays,
        logs: logs,
        calendar: calendar
      )
      if mode == .week {
        weekStrip(days)
      } else {
        monthGrid(days)
      }
    case .error(let message):
      CalendarLoadError(message: message) {
        Task { await viewModel.load(studentID: studentID) }
      }
    }
  }

  private func weekStrip(_ days: [TrainingCalendarDay]) -> some View {
    HStack(spacing: MeetPRSpacing.point6) {
      ForEach(days) { day in
        MeetPRDayChip(
          weekday: weekdayText(day.date),
          date: calendar.component(.day, from: day.date),
          state: v3State(for: day),
          isSelected: day.isSelected,
          width: nil,
          selectedAppearance: .outlined
        ) {
          select(day.date)
        }
      }
    }
  }

  private func monthGrid(_ days: [TrainingCalendarDay]) -> some View {
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: MeetPRSpacing.point5),
      count: 7
    )
    return VStack(spacing: MeetPRSpacing.point5) {
      LazyVGrid(columns: columns, spacing: MeetPRSpacing.point5) {
        ForEach(TrainingCalendarLayout.weekdayLabels(calendar: calendar), id: \.self) { label in
          Text(label)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textDim)
            .frame(maxWidth: .infinity)
        }

        ForEach(days) { day in
          if day.isInDisplayedMonth {
            TrainingMonthDay(
              day: day,
              state: v3State(for: day),
              dayNumber: calendar.component(.day, from: day.date)
            ) {
              select(day.date)
            }
          } else {
            Color.clear.frame(height: MeetPRSpacing.size46)
          }
        }
      }
    }
  }

  private func v3State(for day: TrainingCalendarDay) -> MeetPRDayChip.DayState {
    TrainingCalendarV3State.resolve(
      progress: day.progress,
      date: day.date,
      today: today(),
      calendar: calendar
    )
  }

  private func weekdayText(_ date: Date) -> String {
    TrainingCalendarText.weekday(for: date, calendar: calendar)
  }

  private func movePeriod(by value: Int) {
    displayedDate = TrainingCalendarLayout.move(
      displayedDate,
      mode: mode,
      by: value,
      calendar: calendar
    )
  }

  private func select(_ date: Date) {
    selectedDate = calendar.startOfDay(for: date)
    displayedDate = selectedDate
  }
}

/// The decorative color key under the calendar. The screen owns it (instead
/// of `TrainingCalendarView`) so the collapsed state can drop it from the
/// tree entirely — see `TodayWorkoutScreen`.
struct TrainingCalendarLegend: View {
  var body: some View {
    HStack(spacing: MeetPRSpacing.point14) {
      TrainingCalendarLegendItem(color: Color.MeetPR.success, label: "已完成")
      TrainingCalendarLegendItem(color: Color.MeetPR.gold500, label: "进行中")
      TrainingCalendarLegendItem(color: Color.MeetPR.danger, label: "未完成")
    }
    .accessibilityHidden(true)
  }
}

private struct TrainingCalendarLegendItem: View {
  let color: Color
  let label: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.point5) {
      Circle()
        .fill(color)
        .frame(width: MeetPRSpacing.point6, height: MeetPRSpacing.point6)
      Text(label)
    }
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
    .foregroundStyle(Color.MeetPR.textDim)
  }
}

@Observable
@MainActor
private final class TrainingCalendarViewModel {
  enum State {
    case idle
    case loading
    case loaded(days: [StudentPlanDay], logs: [StudentSetLog])
    case error(String)
  }

  private(set) var state: State = .idle

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository

  init(plans: any StudentPlanRepository, logs: any StudentTrainingLogRepository) {
    self.plans = plans
    self.logs = logs
  }

  func load(studentID: UUID) async {
    let isInitialLoad: Bool
    switch state {
    case .idle:
      isInitialLoad = true
      state = .loading
    case .loading, .loaded, .error:
      isInitialLoad = false
    }
    do {
      let days = try await plans.fetchCycleDays(studentID: studentID)
      let fetchedLogs: [StudentSetLog]
      if let range = Self.dateRange(for: days) {
        fetchedLogs = try await logs.fetchLogs(studentID: studentID, in: range)
      } else {
        fetchedLogs = []
      }
      state = .loaded(days: days, logs: fetchedLogs)
    } catch {
      if error.isTaskCancellation {
        if isInitialLoad { state = .idle }
        return
      }
      if case .loaded = state { return }
      state = .error(TodayWorkoutViewModel.loadErrorMessage(for: error))
    }
  }

  private static func dateRange(for days: [StudentPlanDay]) -> ClosedRange<Date>? {
    guard let first = days.map(\.date).min(), let last = days.map(\.date).max() else {
      return nil
    }
    let start = Calendar.current.startOfDay(for: first)
    let end = Calendar.current.startOfDay(for: last).addingTimeInterval(86_400 - 1)
    return start...end
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CalendarLoadError: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Image(systemName: "exclamationmark.triangle")
      Text(message)
        .lineLimit(1)
      Spacer()
      Button("重试", action: retry)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
    }
    .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
    .foregroundStyle(Color.MeetPR.textSecondary)
    .padding(.vertical, MeetPRSpacing.point10)
  }
}
