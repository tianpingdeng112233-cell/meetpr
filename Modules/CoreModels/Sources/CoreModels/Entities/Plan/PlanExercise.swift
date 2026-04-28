import Foundation

public struct PlanExercise: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let planDayID: UUID
  public let exerciseID: UUID
  public let isMainLift: Bool
  public let sortOrder: Int
  public let notes: String?

  public init(
    id: UUID,
    planDayID: UUID,
    exerciseID: UUID,
    isMainLift: Bool,
    sortOrder: Int,
    notes: String? = nil
  ) {
    self.id = id
    self.planDayID = planDayID
    self.exerciseID = exerciseID
    self.isMainLift = isMainLift
    self.sortOrder = sortOrder
    self.notes = notes
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planDayID = "planDayId"
    case exerciseID = "exerciseId"
    case isMainLift
    case sortOrder
    case notes
  }
}
