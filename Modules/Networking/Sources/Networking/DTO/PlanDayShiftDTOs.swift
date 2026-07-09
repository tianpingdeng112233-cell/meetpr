import Foundation

public struct ShiftPlanDayRequestDTO: Encodable, Equatable, Sendable {
  public let shiftedToDate: String

  public init(shiftedToDate: Date) {
    self.shiftedToDate = WireFormatting.dateOnlyString(from: shiftedToDate)
  }

  public init(shiftedToDate: String) {
    self.shiftedToDate = shiftedToDate
  }
}

public struct PlanDayShiftDTO: Decodable, Equatable, Sendable {
  public let id: UUID
  public let planDayID: UUID
  public let shiftedToDate: Date
  public let createdAt: Date

  public init(
    id: UUID,
    planDayID: UUID,
    shiftedToDate: Date,
    createdAt: Date
  ) {
    self.id = id
    self.planDayID = planDayID
    self.shiftedToDate = shiftedToDate
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planDayID = "planDayId"
    case shiftedToDate
    case createdAt
  }
}
