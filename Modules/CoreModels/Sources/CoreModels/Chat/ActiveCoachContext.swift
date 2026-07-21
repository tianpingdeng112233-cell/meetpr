import Foundation

public struct ActiveCoachContext: Codable, Hashable, Sendable {
  public let coachID: UUID
  public let coachDisplayName: String

  public init(coachID: UUID, coachDisplayName: String) {
    self.coachID = coachID
    self.coachDisplayName = coachDisplayName
  }

  private enum CodingKeys: String, CodingKey {
    case coachID = "coachId"
    case coachDisplayName
  }
}
