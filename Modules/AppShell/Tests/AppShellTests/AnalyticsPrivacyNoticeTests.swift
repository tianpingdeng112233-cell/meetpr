import Foundation
import Networking
import SwiftUI
import Testing
import ViewInspector

@testable import AppShell

@MainActor
@Test func legalNoticeRequiresCurrentVersionEvenForPreviouslyConfirmedUsers() throws {
  let suite = "legal-consent-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }

  #expect(AnalyticsRootModifier.shouldShowNotice(mode: .live, defaults: defaults))
  #expect(!AnalyticsRootModifier.shouldShowNotice(mode: .disabled, defaults: defaults))
  defaults.set(true, forKey: "meetpr.analytics.privacy_notice_confirmed")
  #expect(AnalyticsRootModifier.shouldShowNotice(mode: .live, defaults: defaults))
  defaults.set("2026-12-01", forKey: "meetpr.legal.accepted_version")
  #expect(!AnalyticsRootModifier.shouldShowNotice(mode: .live, defaults: defaults))
  defaults.set("2026-01-01", forKey: "meetpr.legal.accepted_version")
  #expect(AnalyticsRootModifier.shouldShowNotice(mode: .live, defaults: defaults))
}

@MainActor
@Test func analyticsPrivacyBodyScrollsWithoutTruncationAndKeepsActionsOutside() throws {
  let suite = "legal-consent-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  var confirmations = 0
  let inspected = try AnalyticsPrivacyNotice(buildTrack: .global, defaults: defaults) {
    confirmations += 1
  }.inspect()
  let scroll = try inspected.find(ViewType.ScrollView.self)
  let body = try scroll.find(text: AppShellStrings.analyticsPrivacyBody(for: .global))
  #expect(try body.lineLimit() == nil)
  #expect(try body.fixedSize().vertical)
  #expect(scroll.findAll(ViewType.Button.self).isEmpty)
  let title = try inspected.find(text: AppShellStrings.analyticsPrivacyTitle)
  #expect(!title.pathToRoot.contains("scrollView"))
  #expect(
    try inspected.find(link: AnalyticsPrivacyNotice.privacyPolicyURL).url()
      == AnalyticsPrivacyNotice.privacyPolicyURL)
  #expect(
    try scroll.find(link: LegalDocuments.termsURL).url().absoluteString
      == "https://meetpr.app/terms")
  #expect(
    try scroll.find(text: AppShellStrings.legalConsentBody).string()
      == AppShellStrings.legalConsentBody)
  try inspected.find(button: AppShellStrings.agreeAndContinue).tap()
  #expect(defaults.string(forKey: "meetpr.legal.accepted_version") == "2026-12-01")
  #expect(confirmations == 1)
}

@Test func analyticsPrivacyBodySelectsTheRequestedBuildTrack() {
  #expect(
    AppShellStrings.analyticsPrivacyBodyKey(for: .global)
      == "appShell.privacy.analytics.body.global")
  #expect(
    AppShellStrings.analyticsPrivacyBodyKey(for: .china)
      == "appShell.privacy.analytics.body")
}

@MainActor
@Test func decliningConsentOnlyOffersReviewAndDoesNotAccept() async throws {
  let suite = "legal-consent-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  var confirmations = 0
  let sut = AnalyticsPrivacyNotice(defaults: defaults) { confirmations += 1 }
  try await ViewHosting.host(sut) {
    try sut.inspect().find(viewWithAccessibilityIdentifier: "legal.decline").button().tap()
    let declined = try sut.inspect()
    #expect(declined.findAll(ViewType.Button.self).count == 1)
    #expect(declined.findAll(ViewType.Link.self).isEmpty)
    #expect(throws: Never.self) {
      try declined.find(viewWithAccessibilityIdentifier: "legal.required")
    }
    #expect(defaults.string(forKey: "meetpr.legal.accepted_version") == nil)
    #expect(confirmations == 0)
    try declined.find(viewWithAccessibilityIdentifier: "legal.review").button().tap()
    let reviewing = try sut.inspect()
    #expect(
      try reviewing.find(link: LegalDocuments.termsURL).url()
        == LegalDocuments.termsURL)
    #expect(
      try reviewing.find(link: AnalyticsPrivacyNotice.privacyPolicyURL).url()
        == AnalyticsPrivacyNotice.privacyPolicyURL)
    #expect(defaults.string(forKey: "meetpr.legal.accepted_version") == nil)
    #expect(confirmations == 0)
  }
}

@Test func analyticsPrivacyCopyUsesAccountLifetimeInBothTracksAndLanguages() throws {
  let catalogURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "Sources/AppShell/Resources/Localizable.xcstrings")
  let catalog = try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
  let strings = try #require(catalog["strings"] as? [String: Any])
  for key in ["appShell.privacy.analytics.body", "appShell.privacy.analytics.body.global"] {
    let entry = try #require(strings[key] as? [String: Any], "Missing key: \(key)")
    let localizations = try #require(entry["localizations"] as? [String: Any])
    for language in ["en", "zh-Hans"] {
      let localization = try #require(localizations[language] as? [String: Any])
      let unit = try #require(localization["stringUnit"] as? [String: Any])
      let text = try #require(unit["value"] as? String)
      #expect(!text.contains("90"), "\(key) / \(language)")
      #expect(text.contains(language == "en" ? "while your account exists" : "账号存续期间"))
      #expect(text.contains(language == "en" ? "becomes anonymous records" : "无法识别你的匿名记录"))
    }
  }
}
