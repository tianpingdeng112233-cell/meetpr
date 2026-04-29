import Foundation
import SwiftData

@Model
public final class DraftPlanDay {
  public var id: UUID = UUID()
  public var dayOfWeek: Int = 1
  public var weekNumber: Int = 1
  public var sortOrder: Int = 0
  public var assignedLiftFamilyRawValues: [String] = []
  public var plan: DraftTrainingPlan?

  @Relationship(deleteRule: .cascade, inverse: \DraftPlanExercise.day)
  public var draftExercises: [DraftPlanExercise] = []

  public init(
    id: UUID = UUID(),
    dayOfWeek: Int,
    weekNumber: Int = 1,
    sortOrder: Int,
    assignedLiftFamilyRawValues: [String] = [],
    plan: DraftTrainingPlan? = nil
  ) {
    self.id = id
    self.dayOfWeek = dayOfWeek
    self.weekNumber = weekNumber
    self.sortOrder = sortOrder
    self.assignedLiftFamilyRawValues = assignedLiftFamilyRawValues
    self.plan = plan
  }
}
