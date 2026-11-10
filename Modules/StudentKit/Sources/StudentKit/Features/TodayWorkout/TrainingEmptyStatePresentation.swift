import CoreModels
import Foundation

enum TrainingEmptyStatePresentation: Equatable, Sendable {
  case firstPlan
  case nextWeek(week: Int, completedSessions: Int)
  case completed(weeks: Int)

  static func resolve(plan: StudentPlanView?, now: Date = Date()) -> Self? {
    guard let plan, !plan.days.isEmpty else { return .firstPlan }
    let sequence = StudentPlanSequence(days: plan.days)
    guard sequence.cursorDay == nil,
      TrainingDayPresentation.completedToday(in: plan.days, now: now) == nil
    else { return nil }
    let lastWeek = plan.days.map(\.weekNumber).max() ?? plan.weekIndex
    let totalWeeks: Int
    if let end = plan.endDate {
      let count =
        PlanCalendarDayIdentity.utcCalendar.dateComponents(
          [.day], from: plan.startDate, to: end
        ).day ?? 0
      totalWeeks = max(lastWeek, count / 7 + 1)
    } else {
      totalWeeks = lastWeek
    }
    if lastWeek < totalWeeks {
      return .nextWeek(
        week: lastWeek + 1,
        completedSessions: plan.days.filter { $0.weekNumber == lastWeek }.count)
    }
    return .completed(weeks: totalWeeks)
  }

  var heading: String {
    if case .nextWeek(let week, _) = self { return "W\(week)" }
    return StudentStrings.localized(.studentRootView002)
  }

  func title(coach: String) -> String {
    switch self {
    case .firstPlan: StudentStrings.replacing(.trainingWaitingFirst, values: [coach])
    case .nextWeek(let week, _):
      StudentStrings.replacing(.trainingWaitingWeek, values: [coach, String(week)])
    case .completed(let weeks):
      StudentStrings.replacing(.trainingPlanFinished, values: [String(weeks)])
    }
  }

  func detail(coach: String) -> String {
    switch self {
    case .firstPlan: StudentStrings.localized(.trainingWaitingFirstHelp)
    case .nextWeek(let week, let sessions):
      StudentStrings.replacing(
        .trainingWaitingWeekHelp, values: [String(week - 1), String(sessions)])
    case .completed: StudentStrings.replacing(.trainingPlanFinishedHelp, values: [coach])
    }
  }
}
