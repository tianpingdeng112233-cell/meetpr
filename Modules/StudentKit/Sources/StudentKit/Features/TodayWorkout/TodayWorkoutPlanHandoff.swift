import CoreModels
import Foundation

public struct TodayWorkoutPlanHandoff: Equatable, Sendable {
  let id: UUID
  let plan: StudentPlanView
  let date: Date
  let existingLogs: [StudentSetLog]

  init(
    plan: StudentPlanView,
    date: Date,
    existingLogs: [StudentSetLog]
  ) {
    id = UUID()
    self.plan = plan
    self.date = date
    self.existingLogs = existingLogs
  }
}
