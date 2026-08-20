import CoreModels
import Foundation
import Observation
import RepositoryContracts

struct DashboardProfileMetrics: Equatable, Sendable {
  let bodyWeightText: String?
  let competition: CompetitionCountdown?

  var isEmpty: Bool {
    bodyWeightText == nil && competition == nil
  }
}

struct CompetitionCountdown: Equatable, Sendable {
  let days: Int
  let dateText: String
}

enum CompetitionCountdownPresenter {
  static func metrics(
    from profile: OnboardingProfile?,
    now: Date,
    calendar: Calendar
  ) -> DashboardProfileMetrics {
    DashboardProfileMetrics(
      bodyWeightText: profile?.weightKg.map { "\(StudentFormatting.decimal($0)) kg" },
      competition: countdown(from: profile, now: now, calendar: calendar)
    )
  }

  static func countdown(
    from profile: OnboardingProfile?,
    now: Date,
    calendar: Calendar
  ) -> CompetitionCountdown? {
    guard profile?.isCompeting == true,
      let dateText = profile?.competitionDate,
      let days = daysUntil(competitionDate: dateText, now: now, calendar: calendar),
      days >= 0
    else {
      return nil
    }
    return CompetitionCountdown(days: days, dateText: dateText)
  }

  static func daysUntil(
    competitionDate: String,
    now: Date,
    calendar: Calendar
  ) -> Int? {
    guard let competitionDay = localDate(from: competitionDate, calendar: calendar) else {
      return nil
    }
    let today = calendar.startOfDay(for: now)
    let target = calendar.startOfDay(for: competitionDay)
    return calendar.dateComponents([.day], from: today, to: target).day
  }

  private static func localDate(from string: String, calendar: Calendar) -> Date? {
    let parts = string.split(separator: "-")
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2])
    else {
      return nil
    }
    return calendar.date(
      from: DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day
      )
    )
  }
}

@Observable
@MainActor
final class DashboardProfileMetricsViewModel {
  enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(DashboardProfileMetrics)
    case error(String)
  }

  private(set) var state: State = .idle

  @ObservationIgnored private let onboarding: any OnboardingProfileReading
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private let calendar: Calendar

  init(
    onboarding: any OnboardingProfileReading,
    now: @escaping @Sendable () -> Date = { Date() },
    calendar: Calendar = .current
  ) {
    self.onboarding = onboarding
    self.now = now
    self.calendar = calendar
  }

  var metrics: DashboardProfileMetrics? {
    guard case .loaded(let metrics) = state else {
      return nil
    }
    return metrics
  }

  func load(studentID: UUID) async {
    let isInitialLoad = state == .idle
    if isInitialLoad { state = .loading }
    do {
      let profile = try await onboarding.fetchProfile(studentId: studentID)
      state = .loaded(
        CompetitionCountdownPresenter.metrics(
          from: profile,
          now: now(),
          calendar: calendar
        )
      )
    } catch {
      if error.isTaskCancellation {
        if isInitialLoad { state = .idle }
        return
      }
      if case .loaded = state { return }
      state = .error(error.localizedDescription)
    }
  }
}
