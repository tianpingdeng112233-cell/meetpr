import CoreModels
import Foundation

/// Coach-side invite code management (spec 031). Maps 1:1 onto the backend
/// /coach/invite-codes endpoints; the backend is the source of truth — the
/// UI re-lists after every mutation instead of patching local state.
public protocol InviteCodeRepository: Sendable {
  /// `expiresInDays` is required (1-365) when `type == .timeLimited` and must
  /// be nil otherwise (backend zod superRefine).
  /// Creating a personal_permanent code auto-revokes the previous active one
  /// in the same backend transaction (backend spec 005 D6).
  func createCode(type: InviteCodeType, label: String?, expiresInDays: Int?) async throws
    -> InviteCode
  /// All codes including revoked ones, created_at DESC (backend ordering
  /// passed through untouched).
  func listCodes() async throws -> [InviteCode]
  /// Idempotent. A foreign code yields 404 INVITE_CODE_NOT_FOUND
  /// (`BindRequestError.notFound`).
  func revokeCode(id: UUID) async throws
}
