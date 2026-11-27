import Foundation

enum LegalDocuments {
  static let privacyPolicyURL =
    URL(string: "https://meetpr.app/privacy") ?? URL(fileURLWithPath: "/")
  static let termsURL = URL(string: "https://meetpr.app/terms") ?? URL(fileURLWithPath: "/")
  static let version = "2026-12-01"
  static let acceptedVersionKey = "meetpr.legal.accepted_version"
}
