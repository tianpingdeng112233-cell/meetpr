import Foundation
import Testing

@testable import CoachKit

@Test func competitionCountdownMapsDateOnlyToPillText() throws {
  var calendar = Calendar(identifier: .gregorian)
  let timeZone = try #require(TimeZone(secondsFromGMT: 0))
  calendar.timeZone = timeZone
  let now = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 15))
  )

  #expect(
    CompetitionCountdownText.make(
      competitionDate: "2026-07-21",
      relativeTo: now,
      timeZone: timeZone
    ) == "D-3"
  )
  #expect(
    CompetitionCountdownText.make(
      competitionDate: "2026-07-18",
      relativeTo: now,
      timeZone: timeZone
    ) == "D-0"
  )
  #expect(
    CompetitionCountdownText.make(
      competitionDate: "2026-07-17",
      relativeTo: now,
      timeZone: timeZone
    ) == nil
  )
  #expect(
    CompetitionCountdownText.make(
      competitionDate: "not-a-date",
      relativeTo: now,
      timeZone: timeZone
    ) == nil
  )
}

@Test func competitionCountdownAlwaysUsesGregorianDateSemantics() throws {
  let timeZone = try #require(TimeZone(secondsFromGMT: 0))
  var buddhist = Calendar(identifier: .buddhist)
  buddhist.timeZone = timeZone
  let now = try #require(
    buddhist.date(from: DateComponents(year: 2569, month: 7, day: 18, hour: 15))
  )

  #expect(
    CompetitionCountdownText.make(
      competitionDate: "2026-07-21",
      relativeTo: now,
      timeZone: timeZone
    ) == "D-3"
  )
}

@Test func attendanceCompletionMapsToGrayscaleTone() {
  #expect(
    RosterAttendanceBarTone.map(CoachStudentRecentWeek(trainedDays: 0, plannedDays: 0))
      == .empty
  )
  #expect(
    RosterAttendanceBarTone.map(CoachStudentRecentWeek(trainedDays: 1, plannedDays: 0))
      == .empty
  )
  #expect(
    RosterAttendanceBarTone.map(CoachStudentRecentWeek(trainedDays: 0, plannedDays: 3))
      == .dim
  )
  #expect(
    RosterAttendanceBarTone.map(CoachStudentRecentWeek(trainedDays: 2, plannedDays: 3))
      == .medium
  )
  #expect(
    RosterAttendanceBarTone.map(CoachStudentRecentWeek(trainedDays: 3, plannedDays: 3))
      == .bright
  )
  #expect(
    RosterAttendanceBarTone.map(CoachStudentRecentWeek(trainedDays: 4, plannedDays: 3))
      == .bright
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func rosterPresentationHidesMissingDiscoveryFields() {
  let row = StudentRosterViewModel.makeRow(
    summary: CoachStudentSummary(id: UUID(), displayName: "老响应学员", status: .active),
    plan: nil,
    logs: [],
    feedback: [],
    now: Date(timeIntervalSince1970: 1_768_780_800)
  )

  #expect(row.competitionCountdownText == nil)
  #expect(row.attendanceBarTones == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoRosterSeedsDiscoveryFields() async throws {
  let students = try await InMemoryPlanRepository.preview().fetchStudents()

  #expect(students.contains { $0.competitionDate != nil })
  #expect(students.contains { $0.recentFourWeeks?.count == 4 })
}
