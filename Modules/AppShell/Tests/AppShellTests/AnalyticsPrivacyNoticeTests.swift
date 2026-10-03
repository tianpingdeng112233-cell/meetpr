import Foundation
import Networking
import Testing
import ViewInspector

@testable import AppShell

@MainActor
@Test func analyticsPrivacyBodyScrollsWithoutTruncationAndKeepsActionsOutside() throws {
  var confirmations = 0
  let inspected = try AnalyticsPrivacyNotice(buildTrack: .global) { confirmations += 1 }.inspect()
  let scroll = try inspected.find(ViewType.ScrollView.self)
  let body = try scroll.find(text: AppShellStrings.analyticsPrivacyBody(for: .global))
  #expect(try body.lineLimit() == nil)
  #expect(try body.fixedSize().vertical)
  #expect(scroll.findAll(ViewType.Button.self).isEmpty)
  #expect(scroll.findAll(ViewType.Link.self).isEmpty)
  let title = try inspected.find(text: AppShellStrings.analyticsPrivacyTitle)
  #expect(!title.pathToRoot.contains("scrollView"))
  #expect(
    try inspected.find(link: AnalyticsPrivacyNotice.privacyPolicyURL).url()
      == AnalyticsPrivacyNotice.privacyPolicyURL)
  try inspected.find(button: AppShellStrings.acknowledge).tap()
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
