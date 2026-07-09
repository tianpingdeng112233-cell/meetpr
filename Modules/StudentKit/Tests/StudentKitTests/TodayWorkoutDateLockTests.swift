import Foundation
import Testing

@testable import StudentKit

// Spec 049 §2: writes belong to today; future never unlocks; the past needs
// an explicit backfill step.

private let shanghai: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
  return calendar
}()

private func date(_ iso: String) -> Date {
  ISO8601DateFormatter().date(from: iso) ?? Date(timeIntervalSince1970: 0)
}

// 2026-07-04 22:00 Beijing.
private let today = date("2026-07-04T14:00:00Z")

@available(iOS 17.0, macOS 14.0, *)
@Test func todayIsEditable() {
  let mode = TodayWorkoutDateLock.mode(
    selected: today, today: today, backfillUnlocked: false, calendar: shanghai)
  #expect(mode == .editable)
  #expect(mode.allowsWrites)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func futureStaysLockedEvenWhenUnlockRequested() {
  let tomorrow = date("2026-07-05T02:00:00Z")
  let mode = TodayWorkoutDateLock.mode(
    selected: tomorrow, today: today, backfillUnlocked: true, calendar: shanghai)
  #expect(mode == .futureLocked)
  #expect(mode.allowsWrites == false)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func pastLocksUntilExplicitBackfill() {
  let lastMonday = date("2026-06-29T10:00:00Z")
  let locked = TodayWorkoutDateLock.mode(
    selected: lastMonday, today: today, backfillUnlocked: false, calendar: shanghai)
  let backfilling = TodayWorkoutDateLock.mode(
    selected: lastMonday, today: today, backfillUnlocked: true, calendar: shanghai)
  #expect(locked == .pastLocked)
  #expect(locked.allowsWrites == false)
  #expect(backfilling == .pastBackfilling)
  #expect(backfilling.allowsWrites)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func lateEveningStillCountsAsTodayInLocalCalendar() {
  // 2026-07-04 23:30 Beijing = 15:30 UTC — same local day as `today`.
  let lateEvening = date("2026-07-04T15:30:00Z")
  let mode = TodayWorkoutDateLock.mode(
    selected: lateEvening, today: today, backfillUnlocked: false, calendar: shanghai)
  #expect(mode == .editable)
}
