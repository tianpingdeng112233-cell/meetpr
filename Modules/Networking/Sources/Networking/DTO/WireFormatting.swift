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
      preconditionFailure("Date could not be converted to YYYY-MM-DD components.")
    }

    return
      "\(zeroPadded(year, length: 4))-\(zeroPadded(month, length: 2))-\(zeroPadded(day, length: 2))"
  }

  private static func zeroPadded(_ value: Int, length: Int) -> String {
    let rawValue = String(value)
    let paddingCount = max(0, length - rawValue.count)
    return String(repeating: "0", count: paddingCount) + rawValue
  }
}
