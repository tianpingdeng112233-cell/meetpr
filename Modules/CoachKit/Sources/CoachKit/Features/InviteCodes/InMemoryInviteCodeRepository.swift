import CoreModels
import Foundation
import RepositoryContracts

/// Demo/preview invite-code store (spec 031 §9). Simulates the backend core
/// semantics the UI depends on: personal regeneration auto-revokes the
/// previous active personal code, revoke is idempotent, list is created_at
/// DESC. Lazy-expiry timing is NOT replicated (risk 6) — expiry display is
/// client-derived from expires_at either way.
public actor InMemoryInviteCodeRepository: InviteCodeRepository {
  private let coachId: UUID
  private var codes: [InviteCode]
  private let now: @Sendable () -> Date

  public init(
    coachId: UUID = UUID(),
    seed: [InviteCode] = [],
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.coachId = coachId
    self.codes = seed
    self.now = now
  }

  public func createCode(
    type: InviteCodeType,
    label: String?,
    expiresInDays: Int?
  ) async throws -> InviteCode {
    let timestamp = now()
    if type == .personalPermanent {
      codes = codes.map { code in
        guard code.type == .personalPermanent, code.revokedAt == nil else { return code }
        return Self.revoked(code, at: timestamp)
      }
    }

    let code = InviteCode(
      id: UUID(),
      coachId: coachId,
      code: Self.generateCode(),
      type: type,
      maxUses: type == .singleUse ? 1 : nil,
      usedCount: 0,
      expiresAt: type == .timeLimited
        ? expiresInDays.map { timestamp.addingTimeInterval(Double($0) * 86_400) } : nil,
      revokedAt: nil,
      label: label,
      createdAt: timestamp
    )
    codes.insert(code, at: 0)  // created_at DESC
    return code
  }

  public func listCodes() async throws -> [InviteCode] {
    codes
  }

  public func revokeCode(id: UUID) async throws {
    guard let index = codes.firstIndex(where: { $0.id == id }) else {
      throw BindRequestError.notFound
    }
    // Idempotent: re-revoking keeps the original revoked_at.
    guard codes[index].revokedAt == nil else { return }
    codes[index] = Self.revoked(codes[index], at: now())
  }

  // MARK: - DEMO seed (spec 031 D10)

  /// Personal used-23 + one unused single-use + one time-limited expiring
  /// in 6 days.
  public static func demoSeed(coachId: UUID, now: Date = Date()) -> [InviteCode] {
    [
      InviteCode(
        id: UUID(uuid: (0x03, 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01)),
        coachId: coachId,
        code: "DEMO2COACH",
        type: .personalPermanent,
        maxUses: nil,
        usedCount: 23,
        expiresAt: nil,
        revokedAt: nil,
        label: nil,
        createdAt: now.addingTimeInterval(-30 * 86_400)
      ),
      InviteCode(
        id: UUID(uuid: (0x03, 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x02)),
        coachId: coachId,
        code: "XK7MPQ2RVT",
        type: .singleUse,
        maxUses: 1,
        usedCount: 0,
        expiresAt: nil,
        revokedAt: nil,
        label: "给小明",
        createdAt: now.addingTimeInterval(-2 * 86_400)
      ),
      InviteCode(
        id: UUID(uuid: (0x03, 0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x03)),
        coachId: coachId,
        code: "GYMWEEK26A",
        type: .timeLimited,
        maxUses: nil,
        usedCount: 4,
        expiresAt: now.addingTimeInterval(6 * 86_400),
        revokedAt: nil,
        label: "馆活动周",
        createdAt: now.addingTimeInterval(-86_400)
      ),
    ]
  }

  // MARK: - Helpers

  private static func revoked(_ code: InviteCode, at timestamp: Date) -> InviteCode {
    InviteCode(
      id: code.id,
      coachId: code.coachId,
      code: code.code,
      type: code.type,
      maxUses: code.maxUses,
      usedCount: code.usedCount,
      expiresAt: code.expiresAt,
      revokedAt: timestamp,
      label: code.label,
      createdAt: code.createdAt
    )
  }

  private static func generateCode() -> String {
    let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    let characters = (0..<InviteCodeFormat.length).compactMap { _ in alphabet.randomElement() }
    return String(characters)
  }
}
