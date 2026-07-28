import CoreModels
import Foundation

enum DashboardWeekProgressState: Equatable, Sendable {
  case done
  case current
  case upcoming
}

enum DashboardTodayActionState: Equatable, Sendable {
  case hidden
  case primary
  case postponed
}

struct DashboardWeekProgressSegment: Equatable, Identifiable, Sendable {
  let id: UUID
  let state: DashboardWeekProgressState
}

struct DashboardWeekCalendarCell: Identifiable, Sendable {
  let id: Int
  let date: Date
  let weekday: String
  let families: [LiftFamily]
  let isInProgress: Bool
  let isSelected: Bool
}

struct DashboardWeekData: Sendable {
  let days: [StudentPlanDay]
  let logs: [StudentSetLog]
  let weekIndex: Int
}

enum DashboardTodayPresentation {
  static func actionState(
    isSelectedToday: Bool,
    isRestDay: Bool,
    canUndoPlanShift: Bool
  ) -> DashboardTodayActionState {
    guard isSelectedToday else { return .hidden }
    // The undo window is UTC-anchored (spec 054) and can stay open past the
    // device midnight; if the shifted session has already landed on the
    // device's "today", the workout CTA must win over the postponed rest card.
    if canUndoPlanShift, isRestDay { return .postponed }
    return isRestDay ? .hidden : .primary
  }

  static func weekDates(
    containing date: Date,
    calendar: Calendar
  ) -> [Date] {
    let day = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: day)
    let mondayOffset = (weekday + 5) % 7
    let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: day) ?? day
    return (0..<7).compactMap {
      calendar.date(byAdding: .day, value: $0, to: monday)
    }
  }

  static func planDay(
    on selectedDate: Date,
    in days: [StudentPlanDay],
    selectedCalendar: Calendar
  ) -> StudentPlanDay? {
    days.first {
      PlanCalendarDayIdentity.matches(
        planDate: $0.date,
        selectedDate: selectedDate,
        selectedCalendar: selectedCalendar
      )
    }
  }

  static func mondayOffset(
    for date: Date,
    calendar: Calendar
  ) -> Int {
    let weekday = calendar.component(.weekday, from: date)
    return (weekday + 5) % 7
  }

  static func weekCode(
    weekIndex: Int?,
    selectedDate: Date,
    days: [StudentPlanDay],
    selectedCalendar: Calendar
  ) -> String {
    guard let weekIndex else { return "今日" }
    let prefix = "W\(weekIndex)"
    let trainingDayNumber = weekDates(
      containing: selectedDate,
      calendar: selectedCalendar
    )
    .prefix(mondayOffset(for: selectedDate, calendar: selectedCalendar) + 1)
    .reduce(into: 0) { count, date in
      guard
        let day = planDay(
          on: date,
          in: days,
          selectedCalendar: selectedCalendar
        ),
        !day.exercises.isEmpty
      else {
        return
      }
      count += 1
    }
    return trainingDayNumber == 0
      || planDay(
        on: selectedDate,
        in: days,
        selectedCalendar: selectedCalendar
      )?.exercises.isEmpty != false
      ? prefix
      : "\(prefix)D\(trainingDayNumber)"
  }

  static func progressSegments(
    days: [StudentPlanDay],
    logs: [StudentSetLog],
    today: Date,
    selectedCalendar: Calendar
  ) -> [DashboardWeekProgressSegment] {
    days
      .filter { !$0.exercises.isEmpty }
      .sorted { $0.date < $1.date }
      .map { day in
        let dayOffset =
          PlanCalendarDayIdentity.dayOffset(
            fromPlanDate: day.date,
            toSelectedDate: today,
            selectedCalendar: selectedCalendar
          ) ?? 0
        let progress = TrainingDayProgress(day: day, logs: logs)
        let state: DashboardWeekProgressState
        if dayOffset > 0 || progress.state == .complete {
          state = .done
        } else if dayOffset == 0 {
          state = .current
        } else {
          state = .upcoming
        }
        return DashboardWeekProgressSegment(id: day.id, state: state)
      }
  }

  static func calendarCells(
    days: [StudentPlanDay],
    logs: [StudentSetLog],
    selectedDate: Date,
    today: Date,
    selectedCalendar: Calendar
  ) -> [DashboardWeekCalendarCell] {
    weekDates(containing: today, calendar: selectedCalendar)
      .enumerated()
      .map { offset, date in
        let day = planDay(on: date, in: days, selectedCalendar: selectedCalendar)
        return DashboardWeekCalendarCell(
          id: offset,
          date: date,
          weekday: weekdayLetter(offset),
          families: day.map(MainLiftExerciseFamilyResolver.families(in:)) ?? [],
          isInProgress: day.map { TrainingDayProgress(day: $0, logs: logs).state == .partial }
            ?? false,
          isSelected: selectedCalendar.isDate(date, inSameDayAs: selectedDate)
        )
      }
  }

  static func nextTrainingDate(
    after date: Date,
    days: [StudentPlanDay],
    selectedCalendar: Calendar
  ) -> Date? {
    days
      .filter { !$0.exercises.isEmpty }
      .compactMap { day -> (distance: Int, date: Date)? in
        guard
          let offset = PlanCalendarDayIdentity.dayOffset(
            fromPlanDate: day.date,
            toSelectedDate: date,
            selectedCalendar: selectedCalendar
          ),
          offset < 0
        else {
          return nil
        }
        return (-offset, day.date)
      }
      .min { $0.distance < $1.distance }?
      .date
  }

  /// True when the plan day shown for "today" (device calendar) is the same
  /// day the UTC-anchored shift mutation would move (spec 054). They diverge
  /// between 00:00 and 08:00 in UTC+8, where the shift entry must hide.
  static func shiftTargetsSelectedDay(
    _ day: StudentPlanDay,
    now: Date
  ) -> Bool {
    PlanCalendarDayIdentity.matches(
      planDate: day.date,
      selectedDate: now,
      selectedCalendar: PlanCalendarDayIdentity.utcCalendar
    )
  }

  /// Plan-anchored dates format through UTC components (their identity);
  /// device-calendar selection dates must pass the device calendar instead.
  static func monthDayText(
    _ date: Date,
    calendar: Calendar = PlanCalendarDayIdentity.utcCalendar
  ) -> String {
    let components = calendar.dateComponents(
      [.month, .day],
      from: date
    )
    guard let month = components.month, let day = components.day else { return "" }
    return "\(month)月\(day)日"
  }

  static func weekdayLetter(_ offset: Int) -> String {
    ["一", "二", "三", "四", "五", "六", "日"][min(max(offset, 0), 6)]
  }

  static func liftLetter(_ family: LiftFamily) -> String {
    switch family {
    case .squat: "S"
    case .bench: "B"
    case .deadlift: "D"
    }
  }

  static func liftShortName(_ family: LiftFamily) -> String {
    switch family {
    case .squat: "蹲"
    case .bench: "推"
    case .deadlift: "拉"
    }
  }

  static func liftFullName(_ family: LiftFamily) -> String {
    switch family {
    case .squat: "深蹲"
    case .bench: "卧推"
    case .deadlift: "硬拉"
    }
  }

  /// David 2026-07-28: one or two lifts read as full names ("深蹲日",
  /// "深蹲、卧推日"); only three-lift days keep the abbreviated form.
  static func liftSubtitle(_ families: [LiftFamily]) -> String {
    switch families.count {
    case 0: ""
    case 1, 2: families.map(liftFullName).joined(separator: "、") + "日"
    default: families.map(liftShortName).joined(separator: "·")
    }
  }
}
