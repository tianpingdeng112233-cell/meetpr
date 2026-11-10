import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func meetWeightStripUsesLocalTodayAndIgnoresPastMeets() throws {
  let now = try Date("2026-11-10T22:30:00Z", strategy: .iso8601)
  let zone = try #require(TimeZone(secondsFromGMT: 8 * 3600))
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = zone
  let profile = OnboardingProfile(
    userId: UUID(), isCompeting: true, competitionDate: "2026-11-11",
    createdAt: now, updatedAt: now)
  let record = BodyWeightRecord(recordedOn: "2026-11-11", weightKg: Decimal(string: "77.4") ?? 0)
  let model = MeetWeightStripPresentation(
    profile: profile, records: [record], settingOn: false, now: now, calendar: calendar)
  #expect(model.isVisible)
  #expect(model.competitionDays == 0)
  #expect(model.todayWeightKg == record.weightKg)
  let tomorrow = now.addingTimeInterval(86400)
  #expect(
    !MeetWeightStripPresentation(
      profile: profile, records: [record], settingOn: false, now: tomorrow, calendar: calendar
    ).isVisible)
  let weightOnly = MeetWeightStripPresentation(
    profile: nil, records: [record], settingOn: true, now: now, calendar: calendar)
  #expect(weightOnly.isVisible)
  #expect(weightOnly.competitionDays == nil)
  #expect(weightOnly.todayWeightKg == record.weightKg)
  #expect(
    !MeetWeightStripPresentation(
      profile: nil, records: [], settingOn: false, now: now, calendar: calendar
    ).isVisible)
}

@Test func meetStripCopyUsesGenericMeetAndTodayInAllLanguages() throws {
  let now = try Date("2026-11-10T12:00:00Z", strategy: .iso8601)
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
  let cases = [
    ("zh-Hans", "距比赛 3 天", "今天比赛"),
    ("zh-Hant", "距比賽 3 天", "今天比賽"), ("en", "3 days until meet", "Meet day"),
  ]
  for (language, countdown, today) in cases {
    for (date, expected) in [("2026-11-13", countdown), ("2026-11-10", today)] {
      let profile = OnboardingProfile(
        userId: UUID(), isCompeting: true, competitionDate: date,
        createdAt: now, updatedAt: now)
      let model = MeetWeightStripPresentation(
        profile: profile, records: [], settingOn: false, now: now, calendar: calendar)
      #expect(model.competitionText(locale: Locale(identifier: language)) == expected)
    }
  }
}
