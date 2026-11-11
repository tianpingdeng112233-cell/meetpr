import CoreModels
import Foundation
import RepositoryContracts

struct CoachExerciseNoteLoader {
  static func load(
    _ reference: ExerciseRefV1, studentID: UUID, plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository, planning: any PlanRepository
  ) async throws -> StudentExecutionDay {
    let plan = try await plans.fetchCurrentPlan(studentID: studentID)
    let days = plan?.days ?? []
    guard let day = ExerciseNoteDayResolver.resolve(reference, days: days) else {
      throw UnavailableDay()
    }
    let calendar = CoachFeatureCalendar.calendar
    let earliest = min(days.map(\.scheduledDate).min() ?? day.date, day.date)
    let latest = max(Date(), days.map(\.scheduledDate).max() ?? day.date)
    let range = calendar.startOfDay(for: earliest)...latest.addingTimeInterval(86_400)
    let allLogs = try await CoachTrainingLogReader(planning: planning, fallback: logs)
      .fetch(studentID: studentID, range: range)
    let matching = allLogs.filter {
      CoachDayActivity.belongs($0, to: day, on: day.date, days: days, calendar: calendar)
    }
    var result = StudentExecutionDay(
      date: day.date, planDay: day, allLogs: matching, planDays: days)
    if matching.contains(where: \.adhoc) {
      result.exerciseCatalog = try await CoachDayExerciseCatalog.load(planning: planning)
    }
    return result
  }

  struct UnavailableDay: LocalizedError {
    var errorDescription: String? { CoachLocalization.localized("coach.execution.dayUnavailable") }
  }
}
