import Foundation

/// Stable relative timestamps for chat surfaces.
///
/// SwiftUI's `Text(date, style: .relative)` includes seconds and does not match
/// the product's minute/hour/day buckets, so ChatUI keeps the bucket logic and
/// localizes the resulting labels inside its own bundle.
public enum ChatRelativeTime {
  /// Recomputed over the whole visible timeline, including pending items.
  public static func separators(
    timestamps: [Date], now: Date = Date(), locale: Locale = .current,
    calendar: Calendar = .current
  ) -> [Int: String] {
    var result: [Int: String] = [:]
    for index in timestamps.indices {
      if index == 0 || timestamps[index].timeIntervalSince(timestamps[index - 1]) >= 300 {
        result[index] = separatorText(
          timestamps[index], now: now, locale: locale, calendar: calendar)
      }
    }
    return result
  }

  public static func separatorText(
    _ date: Date, now: Date = Date(), locale: Locale = .current, calendar: Calendar = .current
  ) -> String {
    let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    let time = date.formatted(style.hour().minute())
    let days =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
      ).day ?? 0
    let day: String
    switch days {
    case 0:
      return time
    case 1:
      day = ChatStrings.yesterday(locale: locale)
    case 2..<7:
      day = date.formatted(style.weekday(.abbreviated))
    default:
      if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
        day = date.formatted(style.month(.abbreviated).day())
      } else {
        day = date.formatted(style.year().month(.abbreviated).day())
      }
    }
    return "\(day) \(time)"
  }

  static func text(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 {
      return ChatStrings.justNow
    }
    if seconds < 3_600 {
      return ChatStrings.minutesAgo(seconds / 60)
    }
    if seconds < 86_400 {
      return ChatStrings.hoursAgo(seconds / 3_600)
    }
    if seconds < 2_592_000 {
      return ChatStrings.daysAgo(seconds / 86_400)
    }
    if seconds < 31_536_000 {
      return ChatStrings.monthsAgo(seconds / 2_592_000)
    }
    return ChatStrings.yearsAgo(seconds / 31_536_000)
  }
}
