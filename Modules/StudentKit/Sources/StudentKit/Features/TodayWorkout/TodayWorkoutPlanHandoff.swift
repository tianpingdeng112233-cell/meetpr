import CoreModels
import Foundation

public struct TodayWorkoutPlanHandoff: Equatable, Sendable {
  let id: UUID
  let plan: StudentPlanView
  let dayID: UUID
  let existingLogs: [StudentSetLog]

  init(
    plan: StudentPlanView,
    dayID: UUID,
    existingLogs: [StudentSetLog]
  ) {
    id = UUID()
    self.plan = plan
    self.dayID = dayID
    self.existingLogs = existingLogs
  }
}
