import Foundation

public struct PlanDay: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let planID: UUID
  public let dayOfWeek: Int
  public let weekNumber: Int
  public let sortOrder: Int

  public init(
    id: UUID,
    planID: UUID,
    dayOfWeek: Int,
    weekNumber: Int,
    sortOrder: Int
  ) {
    self.id = id
    self.planID = planID
    self.dayOfWeek = dayOfWeek
    self.weekNumber = weekNumber
    self.sortOrder = sortOrder
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planID = "planId"
    case dayOfWeek
    case weekNumber
    case sortOrder
  }
}
