import Foundation

enum CoachTodayFormatting {
  static func dateText(
    _ date: Date,
    calendar: Calendar = CoachFeatureCalendar.calendar,
    locale: Locale = .current
  ) -> String {
    let style = Date.FormatStyle(
      date: .omitted,
      time: .omitted,
      locale: locale,
      calendar: calendar,
      timeZone: calendar.timeZone
    )
    let monthDay = date.formatted(style.month(.wide).day())
    let weekday = date.formatted(style.weekday(.wide))
    return "\(monthDay) · \(weekday)"
  }
}
