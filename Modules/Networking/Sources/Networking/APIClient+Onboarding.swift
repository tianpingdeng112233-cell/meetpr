import Foundation

// Onboarding profile endpoints (spec 032; backend spec 005 §endpoint E).

extension APIClient {
  /// GET /students/:id/onboarding → 200 (self / bonded coach / pending-bind
  /// coach). 404 ONBOARDING_NOT_FOUND when never filled in.
  public func onboardingProfile(
    studentId: UUID,
    accessToken: String
  ) async throws -> OnboardingProfileDTO {
    try await get(path: "/students/\(studentId.uuidString)/onboarding", accessToken: accessToken)
  }

  /// PUT /students/me/onboarding → 200 (re-entrant partial upsert).
  public func upsertOnboarding(
    _ body: OnboardingPatchDTO,
    accessToken: String
  ) async throws -> OnboardingProfileDTO {
    try await put(path: "/students/me/onboarding", body: body, accessToken: accessToken)
  }

  /// POST /students/me/onboarding/complete → 200 (idempotent; 422
  /// ONBOARDING_INCOMPLETE with missing_fields when the gate fails).
  public func completeOnboarding(accessToken: String) async throws -> OnboardingProfileDTO {
    try await post(path: "/students/me/onboarding/complete", accessToken: accessToken)
  }
}
