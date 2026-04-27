import Foundation

public struct CoachProfile: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let userID: UUID
  public let createdAt: Date

  public init(id: UUID, userID: UUID, createdAt: Date) {
    self.id = id
    self.userID = userID
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case userID = "userId"
    case createdAt
  }
}
