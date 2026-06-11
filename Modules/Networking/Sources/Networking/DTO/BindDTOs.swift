import CoreModels
import Foundation

// Wire DTOs for /coach/invite-codes + /bind-requests (spec 031; field names
// verbatim from backend spec 005 §endpoints A/B — snake_case conversion via
// MeetPRCodec, no hand-written CodingKeys needed).

public struct InviteCodeDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let coachId: UUID
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
    coachId: UUID,
    code: String,
    type: InviteCodeType,
    maxUses: Int?,
    usedCount: Int,
    expiresAt: Date?,
    revokedAt: Date?,
    label: String?,
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

  public func toDomain() -> InviteCode {
    InviteCode(
      id: id,
      coachId: coachId,
      code: code,
      type: type,
      maxUses: maxUses,
      usedCount: usedCount,
      expiresAt: expiresAt,
      revokedAt: revokedAt,
      label: label,
      createdAt: createdAt
    )
  }
}

public struct InviteCodesResponseDTO: Codable, Equatable, Sendable {
  public let inviteCodes: [InviteCodeDTO]

  public init(inviteCodes: [InviteCodeDTO]) {
    self.inviteCodes = inviteCodes
  }
}

/// POST /coach/invite-codes body. zod `.strict()`: `expiresInDays` must be
/// omitted (not null) unless type == time_limited, hence the custom encode.
public struct CreateInviteCodeRequestDTO: Encodable, Equatable, Sendable {
  public let type: InviteCodeType
  public let label: String?
  public let expiresInDays: Int?

  public init(type: InviteCodeType, label: String?, expiresInDays: Int?) {
    self.type = type
    self.label = label
    self.expiresInDays = expiresInDays
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(label, forKey: .label)
    try container.encodeIfPresent(expiresInDays, forKey: .expiresInDays)
  }

  private enum CodingKeys: String, CodingKey {
    case type, label, expiresInDays
  }
}

public struct BindRequestDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentId: UUID
  public let coachId: UUID
  public let coachDisplayName: String?
  public let inviteCodeId: UUID?
  public let status: BindRequestStatus
  public let submittedAt: Date
  public let respondedAt: Date?
  public let expiredAt: Date
  public let skipEvaluation: Bool
  public let skipReason: String?

  public init(
    id: UUID,
    studentId: UUID,
    coachId: UUID,
    coachDisplayName: String?,
    inviteCodeId: UUID?,
    status: BindRequestStatus,
    submittedAt: Date,
    respondedAt: Date?,
    expiredAt: Date,
    skipEvaluation: Bool,
    skipReason: String?
  ) {
    self.id = id
    self.studentId = studentId
    self.coachId = coachId
    self.coachDisplayName = coachDisplayName
    self.inviteCodeId = inviteCodeId
    self.status = status
    self.submittedAt = submittedAt
    self.respondedAt = respondedAt
    self.expiredAt = expiredAt
    self.skipEvaluation = skipEvaluation
    self.skipReason = skipReason
  }

  public func toDomain() -> BindRequest {
    BindRequest(
      id: id,
      studentId: studentId,
      coachId: coachId,
      coachDisplayName: coachDisplayName,
      inviteCodeId: inviteCodeId,
      status: status,
      submittedAt: submittedAt,
      respondedAt: respondedAt,
      expiredAt: expiredAt,
      skipEvaluation: skipEvaluation,
      skipReason: skipReason
    )
  }
}

/// GET /bind-requests/mine — `{ "bind_request": {...} | null }`.
public struct MyBindRequestResponseDTO: Codable, Equatable, Sendable {
  public let bindRequest: BindRequestDTO?

  public init(bindRequest: BindRequestDTO?) {
    self.bindRequest = bindRequest
  }
}

/// POST /bind-requests body — `{ "code": ..., "display_name": ... }`.
public struct CreateBindRequestRequestDTO: Encodable, Equatable, Sendable {
  public let code: String
  public let displayName: String

  public init(code: String, displayName: String) {
    self.code = code
    self.displayName = displayName
  }
}
