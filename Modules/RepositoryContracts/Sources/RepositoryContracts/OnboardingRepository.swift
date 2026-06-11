import CoreModels
import Foundation

/// Typed mirror of the backend onboarding machine codes (spec 032 §2).
public enum OnboardingError: Error, Equatable, Sendable {
  /// 422 ONBOARDING_INCOMPLETE — snake_case field names verbatim from the
  /// wire envelope (the wizard maps them onto steps, spec 032 D12).
  case incomplete(missingFields: [String])
  /// 403 ONE_RM_LOCKED — student-side 1RM write after completion.
  case oneRMLocked
  /// 404 ONBOARDING_NOT_FOUND
  case notFound
}

extension OnboardingError {
  /// Machine-code mapping (spec 032 §2). `missingFields` is only consumed
  /// for ONBOARDING_INCOMPLETE; nil means "not an onboarding code".
  public init?(machineCode: String?, missingFields: [String] = []) {
    switch machineCode {
    case "ONBOARDING_INCOMPLETE": self = .incomplete(missingFields: missingFields)
    case "ONE_RM_LOCKED": self = .oneRMLocked
    case "ONBOARDING_NOT_FOUND": self = .notFound
    default: return nil
    }
  }
}

/// Student onboarding archive (spec 032). Maps 1:1 onto the backend
/// /students/me/onboarding endpoints. No cache by design: archive edits must
/// read back consistently; the wizard's local resilience layer is the
/// separate `LocalOnboardingDraftStore`.
public protocol OnboardingRepository: Sendable {
  /// GET /students/:id/onboarding (self). 404 → nil — "never filled in"
  /// is a normal state, not an error.
  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile?
  /// PUT /students/me/onboarding — step-by-step re-entrant upsert.
  /// A patch touching any 1RM field after completion throws
  /// `OnboardingError.oneRMLocked`.
  func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile
  /// POST /students/me/onboarding/complete. Missing required fields throw
  /// `OnboardingError.incomplete`; re-completing is idempotent (200).
  func complete() async throws -> OnboardingProfile
}
