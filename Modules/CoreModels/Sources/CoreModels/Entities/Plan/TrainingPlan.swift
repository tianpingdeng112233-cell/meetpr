import Foundation

public struct TrainingPlan: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let coachID: UUID?
  public let traineeID: UUID
  public let name: String
  public let startDate: Date
  public let endDate: Date
  public let planWeeks: Int
  /// Decodes as `.regular` when absent — pre-033 fixtures and caches carry
  /// no kind (spec 033 §7).
  public let kind: PlanKind
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
    kind: PlanKind = .regular,
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
    self.kind = kind
    self.source = source
    self.sourceTemplateID = sourceTemplateID
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    coachID = try container.decodeIfPresent(UUID.self, forKey: .coachID)
    traineeID = try container.decode(UUID.self, forKey: .traineeID)
    name = try container.decode(String.self, forKey: .name)
    startDate = try container.decode(Date.self, forKey: .startDate)
    endDate = try container.decode(Date.self, forKey: .endDate)
    planWeeks = try container.decode(Int.self, forKey: .planWeeks)
    kind = try container.decodeIfPresent(PlanKind.self, forKey: .kind) ?? .regular
    source = try container.decode(PlanSource.self, forKey: .source)
    sourceTemplateID = try container.decodeIfPresent(UUID.self, forKey: .sourceTemplateID)
    status = try container.decode(PlanStatus.self, forKey: .status)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case coachID = "coachId"
    case traineeID = "traineeId"
    case name
    case startDate
    case endDate
    case planWeeks
    case kind
    case source
    case sourceTemplateID = "sourceTemplateId"
    case status
    case createdAt
    case updatedAt
  }
}
