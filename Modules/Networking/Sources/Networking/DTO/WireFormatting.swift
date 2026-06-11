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

  /// Wire `to` params are exclusive UTC day-starts (wire-contracts-v0.1 §sets),
  /// while repository APIs take `ClosedRange<Date>`. Mapping a closed upper bound
  /// straight through `dateOnlyString` silently drops the bound's own day, so
  /// shift one day forward at the wire boundary.
  public static func exclusiveEndDateOnlyString(closedUpperBound date: Date) -> String {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone

    let nextDay =
      calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
    return dateOnlyString(from: nextDay)
  }

  private static func twoDigit(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}
