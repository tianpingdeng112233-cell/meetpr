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

  static func timeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.setLocalizedDateFormatFromTemplate("HH:mm")
    return formatter.string(from: date)
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
  static func readinessScalesText(_ checkin: ReadinessCheckin) -> String {
    "睡眠 \(checkin.sleepQuality) · 状态 \(checkin.mood) · 压力 \(checkin.stress)"
  }

  /// "疲劳：股四(重) 核心·下背(轻)", ordered by the whitelist chip order;
  /// no fatigue is a legitimate answer and reads "无肌群疲劳".
  static func readinessFatigueText(_ checkin: ReadinessCheckin) -> String {
    let severityByGroup = Dictionary(
      uniqueKeysWithValues: checkin.muscleFatigue.map { ($0.muscleGroup, $0.severity) }
    )
    let items = ReadinessCheckin.allowedMuscleGroups.compactMap { group in
      severityByGroup[group].map { "\(muscleGroupText(group))(\(severityText($0)))" }
    }
    guard !items.isEmpty else { return "无肌群疲劳" }
    return "疲劳：" + items.joined(separator: " ")
  }

  /// Chinese display for the 8 whitelisted readiness muscle groups, aligned
  /// with the student-side check-in sheet copy.
  static func muscleGroupText(_ group: MuscleGroup) -> String {
    switch group {
    case .quad: "股四"
    case .hamstring: "腘绳"
    case .glute: "臀"
    case .back: "背"
    case .chest: "胸"
    case .shoulder: "肩"
    case .triceps: "肱三头"
    case .core: "核心·下背"
    default: group.rawValue
    }
  }

  static func severityText(_ severity: Int) -> String {
    switch severity {
    case 1: "轻"
    case 2: "中"
    default: "重"
    }
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
