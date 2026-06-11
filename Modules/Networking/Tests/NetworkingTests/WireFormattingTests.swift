import Foundation
import Testing

@testable import Networking

private func utcDate(_ iso: String) -> Date {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime]
  guard let date = formatter.date(from: iso) else {
    Issue.record("bad fixture date \(iso)")
    return Date(timeIntervalSince1970: 0)
  }
  return date
}

@Test func dateOnlyStringUsesUTCDay() {
  #expect(WireFormatting.dateOnlyString(from: utcDate("2026-06-11T23:59:59Z")) == "2026-06-11")
  #expect(WireFormatting.dateOnlyString(from: utcDate("2026-06-11T00:00:00Z")) == "2026-06-11")
}

@Test func exclusiveEndKeepsClosedUpperBoundDayInWindow() {
  // A closed upper bound anywhere inside 06-11 must serialize to 06-12 so the
  // backend's exclusive `to` still includes 06-11 logs.
  #expect(
    WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: utcDate("2026-06-11T15:30:00Z"))
      == "2026-06-12")
  #expect(
    WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: utcDate("2026-06-11T00:00:00Z"))
      == "2026-06-12")
}

@Test func exclusiveEndRollsOverMonthAndYear() {
  #expect(
    WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: utcDate("2026-06-30T12:00:00Z"))
      == "2026-07-01")
  #expect(
    WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: utcDate("2026-12-31T23:00:00Z"))
      == "2027-01-01")
}
