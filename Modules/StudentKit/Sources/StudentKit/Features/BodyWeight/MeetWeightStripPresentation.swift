import CoreModels
import Foundation

struct MeetWeightStripPresentation: Equatable, Sendable {
  let competitionDays: Int?
  let todayWeightKg: Decimal?
  let isVisible: Bool

  func competitionText(locale: Locale = .current) -> String? {
    guard let competitionDays else { return nil }
    return competitionDays == 0
      ? StudentStrings.localized(.meetToday, locale: locale)
      : StudentStrings.replacing(
        .meetCountdownDays, values: [String(competitionDays)], locale: locale)
  }

  init(
    profile: OnboardingProfile?, records: [BodyWeightRecord], settingOn: Bool,
    now: Date = Date(), calendar: Calendar = .current
  ) {
    competitionDays =
      CompetitionCountdownPresenter.countdown(
        from: profile, now: now, calendar: calendar)?.days
    let today = BodyWeightDay.string(from: now, timeZone: calendar.timeZone)
    todayWeightKg = records.first { $0.recordedOn == today }?.weightKg
    isVisible = competitionDays != nil || settingOn
  }
}
