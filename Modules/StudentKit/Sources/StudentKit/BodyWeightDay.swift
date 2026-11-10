import Foundation

/// A device-local calendar day; deliberately independent of the training-day cutoff.
enum BodyWeightDay {
  static func string(from date: Date, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let year = parts.year ?? 1970
    let month = parts.month ?? 1
    let day = parts.day ?? 1
    return "\(year)-\(month < 10 ? "0" : "")\(month)-\(day < 10 ? "0" : "")\(day)"
  }
}
