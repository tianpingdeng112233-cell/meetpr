import CoreModels
import Foundation

enum TrainingDayPresentation {
  static func dayName(_ day: StudentPlanDay) -> String {
    let families = MainLiftExerciseFamilyResolver.families(in: day)
    let liftName = liftSubtitle(families)
    return liftName.isEmpty ? StudentStrings.localized(.dashboardTodayPresentation002) : liftName
  }

  static func completedToday(
    in days: [StudentPlanDay],
    now: Date,
    calendar: Calendar = WorkoutDatePolicy.deviceCalendar
  ) -> StudentPlanDay? {
    let range = WorkoutDatePolicy.gymDayRange(containing: now, calendar: calendar)
    return StudentPlanSequence(days: days).orderedDays.last {
      guard let completedAt = $0.completedAt else { return false }
      return range.contains(completedAt)
    }
  }

  static func liftFullName(_ family: LiftFamily, locale: Locale = .current) -> String {
    switch family {
    case .squat: StudentStrings.localized(.dashboardTodayPresentation012, locale: locale)
    case .bench: StudentStrings.localized(.dashboardTodayPresentation013, locale: locale)
    case .deadlift: StudentStrings.localized(.dashboardTodayPresentation014, locale: locale)
    }
  }

  static func liftShortName(_ family: LiftFamily, locale: Locale = .current) -> String {
    switch family {
    case .squat: StudentStrings.localized(.dashboardTodayPresentation015, locale: locale)
    case .bench: StudentStrings.localized(.dashboardTodayPresentation016, locale: locale)
    case .deadlift: StudentStrings.localized(.dashboardTodayPresentation017, locale: locale)
    }
  }

  static func liftLetter(_ family: LiftFamily) -> String {
    switch family {
    case .squat: "S"
    case .bench: "B"
    case .deadlift: "D"
    }
  }

  static func liftSubtitle(_ families: [LiftFamily], locale: Locale = .current) -> String {
    switch families.count {
    case 0: return ""
    case 1, 2:
      let separator = locale.language.languageCode?.identifier == "en" ? " / " : "、"
      let names = families.map { liftFullName($0, locale: locale) }.joined(separator: separator)
      return StudentStrings.replacing(.dashboardTrainingDayName, values: [names], locale: locale)
    default: return families.map { liftShortName($0, locale: locale) }.joined(separator: "·")
    }
  }
}
