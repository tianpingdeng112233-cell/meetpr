import CoreModels
import Foundation

enum CoachStudentFormatting {
  static func statusText(_ status: CoachStudentStatus, locale: Locale = .current) -> String {
    switch status {
    case .active:
      return CoachSharedStrings.active(locale: locale)
    case .inEvaluation(let remainingDays, let remainingHours):
      if remainingDays > 0 {
        return CoachSharedStrings.evaluationDays(remainingDays, locale: locale)
      }
      return CoachSharedStrings.evaluationHours(remainingHours, locale: locale)
    case .abnormal(let reason):
      return abnormalText(reason, locale: locale)
    }
  }

  static func abnormalText(_ reason: AbnormalReason, locale: Locale = .current) -> String {
    switch reason {
    case .noTrainingForDays(let days):
      return CoachSharedStrings.daysNotTrained(days, locale: locale)
    case .stuckOnWeek(let week):
      return CoachSharedStrings.stuckOnWeek(week, locale: locale)
    }
  }

  static func weekdayText(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated))
  }

  static func shortDateText(_ date: Date) -> String {
    date.formatted(.dateTime.month(.defaultDigits).day())
  }

  static func fullDateText(_ date: Date) -> String {
    date.formatted(.dateTime.year().month(.defaultDigits).day())
  }

  static func relativeText(
    _ date: Date,
    now: Date = Date(),
    locale: Locale = .current
  ) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 3_600 {
      return CoachSharedStrings.minutesAgo(max(1, seconds / 60), locale: locale)
    }
    if seconds < 86_400 {
      return CoachSharedStrings.hoursAgo(seconds / 3_600, locale: locale)
    }
    return CoachSharedStrings.daysAgo(seconds / 86_400, locale: locale)
  }

  static func timeText(_ date: Date) -> String {
    date.formatted(.dateTime.hour().minute())
  }

  /// Device-local calendar day "yyyy-MM-dd". Mirrors the student-side
  /// `ReadinessCheckinViewModel.dateOnly` — the readiness `checkin_date`
  /// semantic is the local day, not UTC (spec 030 §日期与时区).
  static func localDayString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  /// "睡眠 4 · 状态 3 · 压力 2" — raw 1-5 values, all three scales point the
  /// same way (5 = best) per spec 030 §C1, so no per-item inversion here.
  static func readinessScalesText(
    _ checkin: ReadinessCheckin,
    locale: Locale = .current
  ) -> String {
    CoachSharedStrings.readinessScales(
      sleep: checkin.sleepQuality,
      mood: checkin.mood,
      stress: checkin.stress,
      locale: locale
    )
  }

  /// "疲劳：股四(重) 核心·下背(轻)", ordered by the whitelist chip order;
  /// no fatigue is a legitimate answer and reads "无肌群疲劳".
  static func readinessFatigueText(
    _ checkin: ReadinessCheckin,
    locale: Locale = .current
  ) -> String {
    let severityByGroup = Dictionary(
      uniqueKeysWithValues: checkin.muscleFatigue.map { ($0.muscleGroup, $0.severity) }
    )
    let items = ReadinessCheckin.allowedMuscleGroups.compactMap { group in
      severityByGroup[group].map {
        "\(muscleGroupText(group, locale: locale))(\(severityText($0, locale: locale)))"
      }
    }
    guard !items.isEmpty else { return CoachSharedStrings.noMuscleFatigue(locale: locale) }
    return CoachSharedStrings.fatigue(items.joined(separator: " "), locale: locale)
  }

  /// Chinese display for the 8 whitelisted readiness muscle groups, aligned
  /// with the student-side check-in sheet copy.
  static func muscleGroupText(_ group: MuscleGroup, locale: Locale = .current) -> String {
    switch group {
    case .quad:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.quadriceps", locale: locale)
    case .hamstring:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.hamstrings", locale: locale)
    case .glute:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.glutes", locale: locale)
    case .back:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.back", locale: locale)
    case .chest:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.chest", locale: locale)
    case .shoulder:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.shoulder", locale: locale)
    case .triceps:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.triceps", locale: locale)
    case .core:
      CoachSharedStrings.muscleGroup("coach.shared.muscle.coreAndLowerBack", locale: locale)
    default:
      group.rawValue
    }
  }

  static func severityText(_ severity: Int, locale: Locale = .current) -> String {
    CoachSharedStrings.severity(severity, locale: locale)
  }
}

enum CoachFeatureCalendar {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    return calendar
  }

  /// StudentPlanDay.date is a date-only plan anchor. Backend-decoded anchors may
  /// be UTC midnight, but set logs must be bucketed by the athlete's device-local
  /// calendar day so UTC+8 early-morning training stays attached to the visible day.
  static func startOfDay(_ date: Date, calendar: Calendar = Self.calendar) -> Date {
    calendar.startOfDay(for: date)
  }

  static func endOfDay(_ date: Date, calendar: Calendar = Self.calendar) -> Date {
    calendar.date(
      byAdding: DateComponents(day: 1, second: -1), to: startOfDay(date, calendar: calendar))
      ?? date
  }

  static func dateRange(
    starting startDate: Date,
    days: Int,
    calendar: Calendar = Self.calendar
  ) -> ClosedRange<Date> {
    let start = startOfDay(startDate, calendar: calendar)
    let endDate = calendar.date(byAdding: .day, value: max(0, days - 1), to: start) ?? start
    return start...endOfDay(endDate, calendar: calendar)
  }

  static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = Self.calendar) -> Bool {
    calendar.isDate(lhs, inSameDayAs: rhs)
  }
}
