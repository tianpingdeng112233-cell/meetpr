import Foundation

public struct PlanDayCompletionDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let planDayID: UUID
  public let studentID: UUID
  public let source: String
  public var actualCompletionDate: String?
  public let completedAt: Date

  public init(
    id: UUID,
    planDayID: UUID,
    studentID: UUID,
    source: String,
    completedAt: Date
  ) {
    self.id = id
    self.planDayID = planDayID
    self.studentID = studentID
    self.source = source
    self.completedAt = completedAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planDayID = "planDayId"
    case studentID = "studentId"
    case source
    case completedAt, actualCompletionDate
  }
}
