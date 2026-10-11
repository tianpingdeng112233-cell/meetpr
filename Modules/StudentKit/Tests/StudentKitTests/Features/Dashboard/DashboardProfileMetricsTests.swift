import CoreModels
import Foundation
import RepositoryContracts
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
  #expect(withWeight.bodyWeightText == "76.00 kg")
  #expect(withWeight.competition == nil)

  let withoutWeight = CompetitionCountdownPresenter.metrics(
    from: profile(weightKg: nil, isCompeting: false, competitionDate: nil),
    now: now,
    calendar: localCalendar
  )
  #expect(withoutWeight.bodyWeightText == nil)
  #expect(withoutWeight.isEmpty)
}

@MainActor
@Test func loadedEmptyMetricsRemainAvailableForDashboardPlaceholders() async throws {
  let viewModel = DashboardProfileMetricsViewModel(
    onboarding: EmptyOnboardingProfileReader()
  )

  await viewModel.load(studentID: UUID())

  #expect(
    viewModel.state == .loaded(DashboardProfileMetrics(bodyWeightText: nil, competition: nil)))
  #expect(try #require(viewModel.metrics).isEmpty)
}

@MainActor
@Test func profileMetricsFailureDoesNotMasqueradeAsEmptyMetrics() async {
  let viewModel = DashboardProfileMetricsViewModel(
    onboarding: FailingOnboardingProfileReader()
  )

  await viewModel.load(studentID: UUID())

  guard case .error = viewModel.state else {
    Issue.record("Expected error state")
    return
  }
  #expect(viewModel.metrics == nil)
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

private actor EmptyOnboardingProfileReader: OnboardingProfileReading {
  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    nil
  }
}

private actor FailingOnboardingProfileReader: OnboardingProfileReading {
  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    throw ProfileMetricsTestError.failed
  }
}

private enum ProfileMetricsTestError: Error {
  case failed
}

@Test func spec085MetricsPreserveLegacyMeetAndShowTwoDecimals() throws {
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let calendar = try calendar(timeZoneID: "Europe/London")
  for (weight, expected) in [(Decimal(83), "83.00 kg"), (Decimal(string: "83.5") ?? 0, "83.50 kg")]
  {
    let snapshot = OnboardingProfile(
      userId: UUID(), weightKg: weight, isCompeting: true,
      competitionDate: "2026-06-16", targetWeightClass: "83kg", noteToCoach: "Original note",
      createdAt: now, updatedAt: now)
    let metrics = CompetitionCountdownPresenter.metrics(
      from: snapshot, now: now, calendar: calendar)
    #expect(metrics.bodyWeightText == expected)
    #expect(metrics.competition?.days == 2)
    #expect(metrics.competition?.weightClassText == "83kg")
    #expect(snapshot.weightKg == weight)
    #expect(snapshot.targetWeightClass == "83kg")
  }
  let noClass = CompetitionCountdownPresenter.metrics(
    from: profile(isCompeting: true, competitionDate: "2026-06-16"), now: now, calendar: calendar)
  #expect(noClass.competition?.weightClassText == nil)
  for competing: Bool? in [nil, false, true] {
    let noDate = CompetitionCountdownPresenter.metrics(
      from: profile(isCompeting: competing, competitionDate: nil), now: now, calendar: calendar)
    #expect(noDate.competition == nil)
  }
}
