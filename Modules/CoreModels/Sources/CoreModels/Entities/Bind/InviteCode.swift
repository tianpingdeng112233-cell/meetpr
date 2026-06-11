import Foundation

/// Coach invite code (spec 031). Field-for-field mirror of the backend
/// invite_codes wire shape (backend spec 005 §endpoint A) — do not add
/// client-only fields here; computed status lives in the coach UI layer
/// (spec 031 D7: status is derived at read time, the wire has no status).
public struct InviteCode: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let coachId: UUID
  /// 10 chars, uppercase, alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
  /// (backend spec 005 D4; mirrored in `InviteCodeFormat`).
  public let code: String
  public let type: InviteCodeType
  /// 1 for single_use; nil otherwise.
  public let maxUses: Int?
  public let usedCount: Int
  /// Set for time_limited codes only.
  public let expiresAt: Date?
  public let revokedAt: Date?
  public let label: String?
  public let createdAt: Date

  public init(
    id: UUID,
    coachId: UUID,
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
    self.coachId = coachId
    self.code = code
    self.type = type
    self.maxUses = maxUses
    self.usedCount = usedCount
    self.expiresAt = expiresAt
    self.revokedAt = revokedAt
    self.label = label
    self.createdAt = createdAt
  }
}
