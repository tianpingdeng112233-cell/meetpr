import Foundation

/// Consent copy for the first video upload, centralized for easy replacement.
///
/// PLACEHOLDER — needs legal review before public TestFlight (spec 027
/// §隐私同意法律 review 缺口). V0.1 internal-test wording only; consent is
/// recorded locally (UserDefaults) because backend spec 004 deferred the
/// `privacy_consents` ledger to a later consumer-spec increment.
enum VideoPrivacyCopy {
  static let consentTitle = "视频上传须知"
  static let consentBody =
    "你上传的训练视频将仅你绑定的教练可见。MeetPR 不会向其他人公开你的视频。"
  static let consentAgree = "同意上传"
  static let consentDecline = "不上传"
}
