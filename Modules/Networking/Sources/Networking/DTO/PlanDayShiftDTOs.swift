import Foundation

public struct ShiftedPlanDayDTO: Decodable, Equatable, Sendable {
  public let dayID: UUID
  public let shiftedToDate: Date

  public init(dayID: UUID, shiftedToDate: Date) {
    self.dayID = dayID
    self.shiftedToDate = shiftedToDate
  }

  private enum CodingKeys: String, CodingKey {
    case dayID = "dayId"
    case shiftedToDate
  }
}

public struct PlanShiftDTO: Decodable, Equatable, Sendable {
  public let batchID: UUID
  public let shiftedDays: [ShiftedPlanDayDTO]
  public let totalOffsetDays: Int

  public init(
    batchID: UUID,
    shiftedDays: [ShiftedPlanDayDTO],
    totalOffsetDays: Int
  ) {
    self.batchID = batchID
    self.shiftedDays = shiftedDays
    self.totalOffsetDays = totalOffsetDays
  }

  private enum CodingKeys: String, CodingKey {
    case batchID = "batchId"
    case shiftedDays
    case totalOffsetDays
  }
}
