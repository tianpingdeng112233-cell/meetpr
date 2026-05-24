import CoreModels
import Foundation

enum CoachStudentFormatting {
  static func statusText(_ status: CoachStudentStatus) -> String {
    switch status {
    case .active:
      return "活跃"
    case .inEvaluation(let remainingDays, let remainingHours):
      if remainingDays > 0 {
        return "评估期 \(remainingDays) 天"
      }
      return "评估期 \(remainingHours) 小时"
    case .abnormal(let reason):
      return abnormalText(reason)
    }
  }

  static func abnormalText(_ reason: AbnormalReason) -> String {
    switch reason {
    case .noTrainingForDays(let days):
      return "\(days) 天未训练"
    case .stuckOnWeek(let week):
      return "W\(week) 停滞"
    }
  }

  static func weekdayText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter.string(from: date)
  }

  static func shortDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.setLocalizedDateFormatFromTemplate("M/d")
    return formatter.string(from: date)
  }

  static func fullDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.setLocalizedDateFormatFromTemplate("yyyy/M/d")
    return formatter.string(from: date)
  }

  static func relativeText(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 3_600 {
      return "\(max(1, seconds / 60)) 分钟前"
    }
    if seconds < 86_400 {
      return "\(seconds / 3_600) 小时前"
    }
    return "\(seconds / 86_400) 天前"
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
