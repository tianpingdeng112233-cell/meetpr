import CoreModels
import Foundation

/// The single source every completion consumer derives from (spec 049 §1):
/// one (days, logs) snapshot → one progress answer per day. The dashboard's
/// today card, week progress bar and day dots, and the training calendar's
/// week/month dots must all go through here — never hand-roll a
/// TrainingDayProgress from a private logs slice.
struct TrainingWeekSnapshot: Equatable, Sendable {
  let days: [StudentPlanDay]
  let logs: [StudentSetLog]

  func day(on date: Date, calendar: Calendar = .current) -> StudentPlanDay? {
    days.first { calendar.isDate($0.date, inSameDayAs: date) }
  }

  func progress(on date: Date, calendar: Calendar = .current) -> TrainingDayProgress {
    TrainingDayProgress(day: day(on: date, calendar: calendar), logs: logs)
  }

  func progress(for day: StudentPlanDay?) -> TrainingDayProgress {
    TrainingDayProgress(day: day, logs: logs)
  }

  /// One segment per training day (rest days excluded), each the day's
  /// set-completion fraction — the dashboard week bar.
  func weekSegments() -> [Double] {
    let values =
      days
      .filter { !$0.exercises.isEmpty }
      .map { day -> Double in
        let progress = progress(for: day)
        guard progress.total > 0 else { return 0 }
        return Double(progress.completed) / Double(progress.total)
      }
    return values.isEmpty ? [0] : values
  }
}
