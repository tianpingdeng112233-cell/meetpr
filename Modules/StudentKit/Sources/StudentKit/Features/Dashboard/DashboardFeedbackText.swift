import CoreModels
import DesignSystem
import Foundation

enum DashboardFeedbackText {
  static func label(for item: CoachFeedback, locale: Locale = .current) -> String {
    guard let video = item.video else {
      return StudentStrings.localized(.dashboardFeedbackText001, locale: locale)
    }
    let exercise =
      StudentExerciseName.display(video, locale: locale)
      ?? StudentStrings.localized(.dashboardFeedbackText002, locale: locale)
    guard let setIndex = video.setIndex else { return exercise }
    // spec 029 C0: set_logs.set_index stays zero-based until the display layer.
    let setNumber = SetIndexDisplay.number(forZeroBasedIndex: setIndex)
    return StudentStrings.replacing(
      .dashboardFeedbackText003,
      values: ["\(exercise)", "\(setNumber)"],
      locale: locale
    )
  }

  static func weekday(for item: CoachFeedback) -> String {
    let date = item.dayDate ?? item.postedAt
    let weekday = Calendar.current.component(.weekday, from: date)
    let offset = (weekday + 5) % 7
    return StudentStrings.replacing(
      .dashboardFeedbackText004, values: ["\(DashboardTodayPresentation.weekdayLetter(offset))"])
  }
}
