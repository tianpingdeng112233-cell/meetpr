import Foundation

public struct InviteCode: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let coachID: UUID
  public let code: String
  public let type: InviteCodeType
  public let maxUses: Int?
  public let usedCount: Int
  public let expiresAt: Date?
  public let revokedAt: Date?
  public let label: String?
  public let createdAt: Date

  public init(
    id: UUID,
    coachID: UUID,
    code: String,
    type: InviteCodeType,
    maxUses: Int? = nil,
    usedCount: Int,
    expiresAt: Date? = nil,
    revokedAt: Date? = nil,
    label: String? = nil,
    createdAt: Date
  ) {
    self.id = id
    self.coachID = coachID
    self.code = code
    self.type = type
    self.maxUses = maxUses
    self.usedCount = usedCount
    self.expiresAt = expiresAt
    self.revokedAt = revokedAt
    self.label = label
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case coachID = "coachId"
    case code
    case type
    case maxUses
    case usedCount
    case expiresAt
    case revokedAt
    case label
    case createdAt
  }
}
