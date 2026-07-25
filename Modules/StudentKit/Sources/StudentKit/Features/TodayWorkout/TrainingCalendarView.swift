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
    self.calendar = calendar
    self.today = today
    self.planRevision = planRevision
    self._selectedDate = selectedDate
    self._displayedDate = State(initialValue: selectedDate.wrappedValue)
    self._viewModel = State(initialValue: TrainingCalendarViewModel(plans: plans, logs: logs))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      toolbar
      content
    }
    .padding(MeetPRSpacing.space3)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
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
      Button(
        action: { movePeriod(by: -1) },
        label: {
          Image(systemName: "chevron.left")
            .frame(width: 32, height: 32)
        }
      )
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityLabel(mode == .week ? "上一周" : "上一月")

      Text(TrainingCalendarLayout.periodTitle(for: displayedDate, mode: mode, calendar: calendar))
        .font(.headline)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)

      Picker("日历模式", selection: $mode) {
        Text("周").tag(TrainingCalendarMode.week)
        Text("月").tag(TrainingCalendarMode.month)
      }
      .pickerStyle(.segmented)
      .frame(width: 112)

      Button(
        action: { movePeriod(by: 1) },
        label: {
          Image(systemName: "chevron.right")
            .frame(width: 32, height: 32)
        }
      )
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityLabel(mode == .week ? "下一周" : "下一月")
    }
    .foregroundStyle(Color.MeetPR.textSecondary)
  }

  @ViewBuilder private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 80)
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
    HStack(spacing: MeetPRSpacing.space2) {
      ForEach(days) { day in
        TrainingCalendarDayButton(day: day, mode: .week) {
          select(day.date)
        }
      }
    }
  }

  private func monthGrid(_ days: [TrainingCalendarDay]) -> some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: MeetPRSpacing.point6), count: 7)
    return LazyVGrid(columns: columns, spacing: MeetPRSpacing.space2) {
      ForEach(TrainingCalendarLayout.weekdayLabels(calendar: calendar), id: \.self) { label in
        Text(label)
          .font(.caption2)
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(maxWidth: .infinity)
      }

      ForEach(days) { day in
        TrainingCalendarDayButton(day: day, mode: .month) {
          select(day.date)
        }
      }
    }
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
    state = .loading
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
        state = .idle
        return
      }
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
private struct TrainingCalendarDayButton: View {
  let day: TrainingCalendarDay
  let mode: TrainingCalendarMode
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      VStack(spacing: MeetPRSpacing.point5) {
        if mode == .week {
          Text(
            day.date.formatted(
              .dateTime.weekday(.abbreviated).locale(Locale(identifier: "zh_CN")))
          )
          .font(.caption2)
        }
        Text(day.date.formatted(.dateTime.day()))
          .font(.subheadline.monospacedDigit().bold())
        Circle()
          .fill(day.progress.state.dotColor)
          .frame(width: 6, height: 6)
      }
      .foregroundStyle(day.isSelected ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
      .frame(maxWidth: .infinity, minHeight: mode == .week ? 44 : 46)
      .background(backgroundColor)
      .opacity(contentOpacity)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.chip)
          .strokeBorder(strokeColor, lineWidth: day.isSelected ? 1.5 : 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.chip))
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(accessibilityLabel)
  }

  private var backgroundColor: Color {
    if day.isSelected { return Color.MeetPR.goldSoft }
    return day.isToday ? Color.MeetPR.surfaceKey : Color.MeetPR.surfaceElevated
  }

  private var strokeColor: Color {
    if day.isSelected { return Color.MeetPR.gold500 }
    return day.isToday ? Color.MeetPR.success : Color.MeetPR.borderDefault
  }

  private var contentOpacity: Double {
    if day.isSelected { return 1 }
    if mode == .month && !day.isInDisplayedMonth { return 0.32 }
    return day.progress.state == .noPlan ? 0.5 : 1
  }

  private var accessibilityLabel: String {
    let date = day.date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
    return day.progress.state == .noPlan ? "\(date)，无计划" : "\(date)，训练日"
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
        .font(.caption)
    }
    .font(.footnote)
    .foregroundStyle(Color.MeetPR.textSecondary)
    .padding(.vertical, MeetPRSpacing.point10)
  }
}
