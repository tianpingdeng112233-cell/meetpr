import Foundation

/// Backend 065 has already matched exercise, effort, reps and daily exercise position.
public struct SetWeightSuggestionRecord: Codable, Equatable, Sendable {
  public let planSetID: UUID
  public let weightKg: Decimal
  public let sourceSetLogID: UUID
  public let sourceLoggedDate: String

  public init(
    planSetID: UUID, weightKg: Decimal, sourceSetLogID: UUID, sourceLoggedDate: String
  ) {
    self.planSetID = planSetID
    self.weightKg = weightKg
    self.sourceSetLogID = sourceSetLogID
    self.sourceLoggedDate = sourceLoggedDate
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    planSetID = try values.decode(UUID.self, forKey: .planSetID)
    weightKg = try values.decodeDecimal(forKey: .weightKg)
    sourceSetLogID = try values.decode(UUID.self, forKey: .sourceSetLogID)
    sourceLoggedDate = try values.decode(String.self, forKey: .sourceLoggedDate)
  }

  private enum CodingKeys: String, CodingKey {
    case planSetID = "planSetId"
    case weightKg
    case sourceSetLogID = "sourceSetLogId"
    case sourceLoggedDate
  }
}
