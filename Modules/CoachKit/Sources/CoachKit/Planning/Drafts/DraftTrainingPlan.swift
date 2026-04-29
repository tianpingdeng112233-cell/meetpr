import Foundation
import SwiftData

@Model
public final class DraftTrainingPlan {
  public var id: UUID = UUID()
  public var traineeID: UUID = UUID()
  public var coachID: UUID?
  public var name: String = ""
  public var startDate: Date = Date()
  public var endDate: Date = Date()
  public var planWeeks: Int = 1
  public var currentStepRawValue: Int = 0
  public var lastSavedAt: Date = Date()

  @Relationship(deleteRule: .cascade, inverse: \DraftPlanDay.plan)
  public var draftDays: [DraftPlanDay] = []

  public init(
    id: UUID = UUID(),
    traineeID: UUID,
    coachID: UUID? = nil,
    name: String,
    startDate: Date,
    endDate: Date,
    planWeeks: Int,
    currentStepRawValue: Int = 0,
    lastSavedAt: Date = Date()
  ) {
    self.id = id
    self.traineeID = traineeID
    self.coachID = coachID
    self.name = name
    self.startDate = startDate
    self.endDate = endDate
    self.planWeeks = planWeeks
    self.currentStepRawValue = currentStepRawValue
    self.lastSavedAt = lastSavedAt
  }
}
