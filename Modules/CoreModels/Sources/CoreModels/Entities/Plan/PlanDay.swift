import Foundation

public struct PlanDay: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let planID: UUID
  public let dayOfWeek: Int
  public let weekNumber: Int
  public let sortOrder: Int
  public let shiftedToDate: Date?

  public init(
    id: UUID,
    planID: UUID,
    dayOfWeek: Int,
    weekNumber: Int,
    sortOrder: Int,
    shiftedToDate: Date? = nil
  ) {
    self.id = id
    self.planID = planID
    self.dayOfWeek = dayOfWeek
    self.weekNumber = weekNumber
    self.sortOrder = sortOrder
    self.shiftedToDate = shiftedToDate
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planID = "planId"
    case dayOfWeek
    case weekNumber
    case sortOrder
    case shiftedToDate
  }
}
