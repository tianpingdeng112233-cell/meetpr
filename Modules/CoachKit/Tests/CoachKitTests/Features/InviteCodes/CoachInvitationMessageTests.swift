import Foundation
import Testing

@testable import CoachKit

@Test func chinaInviteCopyIncludesLinkGroupedCodeAndCoachWhileGlobalCopiesCode() throws {
  let base = try #require(URL(string: "http://localhost:3000"))
  let fixture = try invitationBundle()
  defer { try? FileManager.default.removeItem(at: fixture.bundleURL) }
  let message = CoachInvitationMessage.text(
    code: "XK7MPQ2RVT", coachName: "Coach Example", buildTrack: .china, baseURL: base,
    locale: Locale(identifier: "en"), bundle: fixture)
  #expect(message.contains("http://localhost:3000/i/XK7MPQ2RVT"))
  #expect(message.contains("XK7M PQ2 RVT"))
  #expect(message.hasSuffix("— Coach Example"))
  #expect(
    CoachInvitationMessage.text(
      code: "XK7MPQ2RVT", coachName: nil, buildTrack: .global, baseURL: base) == "XK7MPQ2RVT")
}

private func invitationBundle() throws -> Bundle {
  // SwiftPM copies xcstrings without compiling them; use the real catalog in a temporary bundle.
  let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appending(path: "Sources/CoachKit/Resources/Localizable.xcstrings")
  let catalog = try #require(
    JSONSerialization.jsonObject(with: Data(contentsOf: source)) as? [String: Any])
  let strings = try #require(catalog["strings"] as? [String: Any])
  var translated: [String: String] = [:]
  for key in ["coach.invites.message", "coach.invites.fallbackName"] {
    let entry = try #require(strings[key] as? [String: Any])
    let languages = try #require(entry["localizations"] as? [String: Any])
    let english = try #require(languages["en"] as? [String: Any])
    let unit = try #require(english["stringUnit"] as? [String: String])
    translated[key] = unit["value"]
  }
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "Spec093-\(UUID().uuidString).bundle")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let data = try PropertyListSerialization.data(
    fromPropertyList: translated, format: .xml, options: 0)
  try data.write(to: directory.appending(path: "Localizable.strings"))
  return try #require(Bundle(url: directory))
}
