import Foundation

/// Consent copy for the first video upload, centralized for easy replacement.
///
/// PLACEHOLDER — needs legal review before public TestFlight (spec 027
/// §隐私同意法律 review 缺口). V0.1 internal-test wording only; consent is
/// recorded locally (UserDefaults) because backend spec 004 deferred the
/// `privacy_consents` ledger to a later consumer-spec increment.
enum VideoPrivacyCopy {
  static let consentTitle = StudentStrings.localized(.videoPrivacyCopy001)
  static let consentBody =
    StudentStrings.localized(.videoPrivacyCopy002)
  static let consentAgree = StudentStrings.localized(.videoPrivacyCopy003)
  static let consentDecline = StudentStrings.localized(.videoPrivacyCopy004)
}
