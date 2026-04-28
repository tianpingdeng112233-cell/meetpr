import Foundation

public struct TrainingPlan: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let coachID: UUID?
  public let traineeID: UUID
  public let name: String
  public let startDate: Date
  public let endDate: Date
  public let planWeeks: Int
  public let source: PlanSource
  public let sourceTemplateID: UUID?
  public let status: PlanStatus
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    coachID: UUID? = nil,
    traineeID: UUID,
    name: String,
    startDate: Date,
    endDate: Date,
    planWeeks: Int,
    source: PlanSource,
    sourceTemplateID: UUID? = nil,
    status: PlanStatus,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.coachID = coachID
    self.traineeID = traineeID
    self.name = name
    self.startDate = startDate
    self.endDate = endDate
    self.planWeeks = planWeeks
    self.source = source
    self.sourceTemplateID = sourceTemplateID
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case coachID = "coachId"
    case traineeID = "traineeId"
    case name
    case startDate
    case endDate
    case planWeeks
    case source
    case sourceTemplateID = "sourceTemplateId"
    case status
    case createdAt
    case updatedAt
  }
}
