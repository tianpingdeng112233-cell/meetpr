import CoreModels
import Foundation

enum DashboardWeekProgressState: Equatable, Sendable {
  case done
  case current
  case upcoming
}

struct DashboardWeekProgressSegment: Equatable, Identifiable, Sendable {
  let id: UUID
  let dayNumber: Int
  let recommendedDate: Date
  let state: DashboardWeekProgressState
}

struct DashboardWeekData: Sendable {
  let days: [StudentPlanDay]
  let logs: [StudentSetLog]
  let weekIndex: Int
}

enum DashboardTodayPresentation {
  static func planDay(
    on selectedDate: Date,
    in days: [StudentPlanDay],
    selectedCalendar: Calendar
  ) -> StudentPlanDay? {
    days.first {
      PlanCalendarDayIdentity.matches(
        planDate: $0.scheduledDate,
        selectedDate: selectedDate,
        selectedCalendar: selectedCalendar
      )
    }
  }

  /// The cursor order is defined only by backend spec 035 §术语与排序正典.
  static func cursor(in days: [StudentPlanDay]) -> StudentPlanDay? {
    StudentPlanSequence(days: days).cursorDay
  }

  static func currentWeekDays(in days: [StudentPlanDay]) -> [StudentPlanDay] {
    let sequence = StudentPlanSequence(days: days)
    guard let anchor = sequence.cursorDay ?? sequence.orderedDays.last else { return [] }
    return sequence.orderedDays.filter { $0.weekNumber == anchor.weekNumber }
  }

  static func progressSegments(days: [StudentPlanDay]) -> [DashboardWeekProgressSegment] {
    let cursorID = cursor(in: days)?.id
    return currentWeekDays(in: days).map { day in
      DashboardWeekProgressSegment(
        id: day.id,
        dayNumber: day.dayOfWeek,
        recommendedDate: day.scheduledDate,
        state: day.completedAt != nil ? .done : (day.id == cursorID ? .current : .upcoming)
      )
    }
  }

  static func code(for day: StudentPlanDay) -> String {
    "W\(day.weekNumber)D\(day.dayOfWeek)"
  }

  static func recommendedDateText(_ date: Date) -> String {
    let components = PlanCalendarDayIdentity.utcCalendar.dateComponents([.month, .day], from: date)
    guard let month = components.month, let day = components.day else { return "" }
    return StudentStrings.replacing(.dashboardTodayPresentation001, values: ["\(month)", "\(day)"])
  }

  static func dayName(_ day: StudentPlanDay) -> String {
    let families = MainLiftExerciseFamilyResolver.families(in: day)
    let liftName = liftSubtitle(families)
    return liftName.isEmpty ? StudentStrings.localized(.dashboardTodayPresentation002) : liftName
  }

  static func exerciseSummary(_ day: StudentPlanDay) -> String {
    let exerciseCount = day.exercises.count
    let setCount = day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    return StudentStrings.replacing(
      .dashboardTodayPresentation003, values: ["\(exerciseCount)", "\(setCount)"])
  }

  static func completedToday(
    in days: [StudentPlanDay],
    now: Date
  ) -> StudentPlanDay? {
    let range = WorkoutDatePolicy.gymDayRange(containing: now)
    return StudentPlanSequence(days: days).orderedDays.last {
      guard let completedAt = $0.completedAt else { return false }
      return range.contains(completedAt)
    }
  }

  static func monthDayText(
    _ date: Date,
    calendar: Calendar = PlanCalendarDayIdentity.utcCalendar
  ) -> String {
    let components = calendar.dateComponents([.month, .day], from: date)
    guard let month = components.month, let day = components.day else { return "" }
    return StudentStrings.replacing(.dashboardTodayPresentation001, values: ["\(month)", "\(day)"])
  }

  static func headerDateText(_ date: Date, calendar: Calendar) -> String {
    let monthDay = monthDayText(date, calendar: calendar)
    let offset = mondayOffset(for: date, calendar: calendar)
    return StudentStrings.replacing(
      .dashboardTodayPresentation004, values: ["\(monthDay)", "\(weekdayLetter(offset))"])
  }

  static func mondayOffset(for date: Date, calendar: Calendar) -> Int {
    let weekday = calendar.component(.weekday, from: date)
    return (weekday + 5) % 7
  }

  static func weekdayLetter(_ offset: Int) -> String {
    [
      StudentStrings.localized(.dashboardTodayPresentation005),
      StudentStrings.localized(.dashboardTodayPresentation006),
      StudentStrings.localized(.dashboardTodayPresentation007),
      StudentStrings.localized(.dashboardTodayPresentation008),
      StudentStrings.localized(.dashboardTodayPresentation009),
      StudentStrings.localized(.dashboardTodayPresentation010),
      StudentStrings.localized(.dashboardTodayPresentation011),
    ][min(max(offset, 0), 6)]
  }

  static func liftFullName(_ family: LiftFamily) -> String {
    switch family {
    case .squat: StudentStrings.localized(.dashboardTodayPresentation012)
    case .bench: StudentStrings.localized(.dashboardTodayPresentation013)
    case .deadlift: StudentStrings.localized(.dashboardTodayPresentation014)
    }
  }

  static func liftShortName(_ family: LiftFamily) -> String {
    switch family {
    case .squat: StudentStrings.localized(.dashboardTodayPresentation015)
    case .bench: StudentStrings.localized(.dashboardTodayPresentation016)
    case .deadlift: StudentStrings.localized(.dashboardTodayPresentation017)
    }
  }

  static func liftLetter(_ family: LiftFamily) -> String {
    switch family {
    case .squat: "S"
    case .bench: "B"
    case .deadlift: "D"
    }
  }

  static func liftSubtitle(_ families: [LiftFamily]) -> String {
    switch families.count {
    case 0: ""
    case 1, 2:
      StudentStrings.listSeparated(families.map(liftFullName))
        + StudentStrings.localized(.dashboardTodayPresentation011)
    default: families.map(liftShortName).joined(separator: "·")
    }
  }
}
