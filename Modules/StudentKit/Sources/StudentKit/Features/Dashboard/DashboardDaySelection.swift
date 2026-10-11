import CoreModels
import Foundation

struct DashboardDaySelection: Sendable {
  private var selectedDayID: UUID?

  mutating func select(_ dayID: UUID) { selectedDayID = dayID }
  mutating func reset() { selectedDayID = nil }

  func day(in days: [StudentPlanDay], now: Date) -> StudentPlanDay? {
    if let selected = days.first(where: { $0.id == selectedDayID }) { return selected }
    return DashboardTodayPresentation.completedToday(in: days, now: now)
      ?? StudentPlanSequence(days: days).cursorDay
      ?? StudentPlanSequence(days: days).orderedDays.last
  }
}

struct DashboardSessionOverview: Equatable, Sendable {
  let dayID: UUID
  let name: String
  let status: DashboardWeekProgressState
  let summary: String
  let exerciseNames: String

  init(day: StudentPlanDay, cursorID: UUID?, locale: Locale = .current) {
    dayID = day.id
    let families = MainLiftExerciseFamilyResolver.families(in: day)
    name =
      families.isEmpty
      ? StudentStrings.localized(.dashboardTodayPresentation002, locale: locale)
      : DashboardTodayPresentation.liftSubtitle(families, locale: locale)
    status = day.completedAt != nil ? .done : (day.id == cursorID ? .current : .upcoming)
    let exercises = StudentStrings.replacing(
      .overviewExercises, values: ["\(day.exercises.count)"], locale: locale)
    let sets = StudentStrings.replacing(
      .overviewSets, values: ["\(day.exercises.reduce(0) { $0 + $1.prescribedSets.count })"],
      locale: locale)
    summary = StudentStrings.replacing(.overviewSummary, values: [exercises, sets], locale: locale)
    exerciseNames = day.exercises.sorted { $0.sequenceIndex < $1.sequenceIndex }.map { slot in
      if locale.language.languageCode?.identifier == "en",
        let english = slot.exercise.nameEn?.trimmingCharacters(in: .whitespacesAndNewlines),
        !english.isEmpty
      {
        return english
      }
      return slot.exercise.name
    }.joined(separator: " · ")
  }

  var statusText: String {
    switch status {
    case .current: StudentStrings.localized(.todaySession)
    case .done: StudentStrings.localized(.trainingWeekCompleted)
    case .upcoming: StudentStrings.localized(.todayUpcoming)
    }
  }
}
