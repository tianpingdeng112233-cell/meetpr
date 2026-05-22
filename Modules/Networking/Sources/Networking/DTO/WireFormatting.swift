import Foundation

enum WireFormatting {
  static func dateOnlyString(from date: Date) -> String {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

    let components = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year,
      let month = components.month,
      let day = components.day
    else {
      return ""
    }

    return String(format: "%04d-%02d-%02d", year, month, day)
  }
}
