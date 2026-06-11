import Foundation
import SwiftUI

/// "yyyy-MM-dd" ↔ Date in the student's local calendar (the product
/// semantic for birthday / competition day; the wire never sees a Date —
/// spec 032 wire rule, 030 checkinDate precedent).
enum DateOnly {
  static func string(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  static func date(from string: String?) -> Date? {
    guard let string else { return nil }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: string)
  }

  /// Binding adapter for DatePicker over an optional date-only string.
  static func binding(_ source: Binding<String?>, default defaultDate: Date) -> Binding<Date> {
    Binding<Date>(
      get: { date(from: source.wrappedValue) ?? defaultDate },
      set: { source.wrappedValue = string(from: $0) }
    )
  }
}
