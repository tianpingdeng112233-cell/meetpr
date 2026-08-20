import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func cursorDoesNotChangeAcrossDeviceGymDayBoundary() throws {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
  let before = try #require(
    calendar.date(from: DateComponents(year: 2030, month: 1, day: 2, hour: 3, minute: 59))
  )
  let after = before.addingTimeInterval(60)
  let days = [
    StudentPlanDay(id: UUID(), weekNumber: 1, dayOfWeek: 1, date: before, exercises: []),
    StudentPlanDay(id: UUID(), weekNumber: 1, dayOfWeek: 2, date: after, exercises: []),
  ]

  #expect(StudentPlanSequence(days: days).cursorDay?.id == days[0].id)
  #expect(
    WorkoutDatePolicy.gymDayRange(containing: before, calendar: calendar)
      != WorkoutDatePolicy.gymDayRange(containing: after, calendar: calendar))
  #expect(StudentPlanSequence(days: days).cursorDay?.id == days[0].id)
}

@Test func planCalendarIdentityMatchesUTCProjectionToDeviceComponents() throws {
  var shanghai = Calendar(identifier: .gregorian)
  shanghai.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
  let utcDate = try #require(
    PlanCalendarDayIdentity.utcCalendar.date(
      from: DateComponents(year: 2030, month: 1, day: 2)
    )
  )
  let localDate = try #require(
    shanghai.date(from: DateComponents(year: 2030, month: 1, day: 2))
  )

  #expect(
    PlanCalendarDayIdentity.matches(
      planDate: utcDate,
      selectedDate: localDate,
      selectedCalendar: shanghai
    )
  )
}
