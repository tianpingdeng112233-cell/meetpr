import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func countdownUsesLocalCalendarDayAcrossTimeZones() throws {
  let instant = try Date("2026-06-14T23:30:00Z", strategy: .iso8601)
  let tokyo = try calendar(timeZoneID: "Asia/Tokyo")
  let losAngeles = try calendar(timeZoneID: "America/Los_Angeles")

  #expect(
    CompetitionCountdownPresenter.daysUntil(
      competitionDate: "2026-06-16",
      now: instant,
      calendar: tokyo
    ) == 1
  )
  #expect(
    CompetitionCountdownPresenter.daysUntil(
      competitionDate: "2026-06-16",
      now: instant,
      calendar: losAngeles
    ) == 2
  )
}

@Test func expiredCompetitionReturnsNegativeAndIsHidden() throws {
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let localCalendar = try calendar(timeZoneID: "Europe/London")
  let profile = profile(isCompeting: true, competitionDate: "2026-06-13")

  #expect(
    CompetitionCountdownPresenter.daysUntil(
      competitionDate: "2026-06-13",
      now: now,
      calendar: localCalendar
    ) == -1
  )
  #expect(
    CompetitionCountdownPresenter.countdown(
      from: profile,
      now: now,
      calendar: localCalendar
    ) == nil
  )
}

@Test func nonCompetingOrMissingDateHidesCountdown() throws {
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let localCalendar = try calendar(timeZoneID: "Europe/London")

  #expect(
    CompetitionCountdownPresenter.countdown(
      from: profile(isCompeting: false, competitionDate: "2026-07-25"),
      now: now,
      calendar: localCalendar
    ) == nil
  )
  #expect(
    CompetitionCountdownPresenter.countdown(
      from: profile(isCompeting: true, competitionDate: nil),
      now: now,
      calendar: localCalendar
    ) == nil
  )
}

@Test func metricsShowWeightOnlyWhenPresent() throws {
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let localCalendar = try calendar(timeZoneID: "Europe/London")

  let withWeight = CompetitionCountdownPresenter.metrics(
    from: profile(weightKg: 76, isCompeting: false, competitionDate: nil),
    now: now,
    calendar: localCalendar
  )
  #expect(withWeight.bodyWeightText == "76 kg")
  #expect(withWeight.competition == nil)

  let withoutWeight = CompetitionCountdownPresenter.metrics(
    from: profile(weightKg: nil, isCompeting: false, competitionDate: nil),
    now: now,
    calendar: localCalendar
  )
  #expect(withoutWeight.bodyWeightText == nil)
  #expect(withoutWeight.isEmpty)
}

private func calendar(timeZoneID: String) throws -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
  return calendar
}

private func profile(
  weightKg: Decimal? = nil,
  isCompeting: Bool?,
  competitionDate: String?
) -> OnboardingProfile {
  OnboardingProfile(
    userId: UUID(),
    weightKg: weightKg,
    isCompeting: isCompeting,
    competitionDate: competitionDate,
    createdAt: Date(),
    updatedAt: Date()
  )
}
