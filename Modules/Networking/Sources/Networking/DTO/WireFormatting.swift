import Foundation

public enum WireFormatting {
  public static func dateOnlyString(from date: Date) -> String {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

    let components = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year,
      let month = components.month,
      let day = components.day
    else {
      return ""
    }

    return "\(year)-\(twoDigit(month))-\(twoDigit(day))"
  }

  private static func twoDigit(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}
