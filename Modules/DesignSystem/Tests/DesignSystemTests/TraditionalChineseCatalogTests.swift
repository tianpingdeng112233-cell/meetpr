import Foundation
import Testing

struct TraditionalChineseCatalogTests {
  private let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()

  @Test func everyCatalogPreservesTraditionalChineseStructureAndPlaceholders() throws {
    let paths =
      ["MeetPR/Resources", "Widgets/MeetPRWidgets"]
      + [
        "Analytics", "AppShell", "ChatUI", "CoachKit", "CoreModels", "DesignSystem",
        "RepositoryContracts", "StudentKit",
      ].map { "Modules/\($0)/Sources/\($0)/Resources" }
    let forbidden = try String(
      contentsOf: root.appending(path: "scripts/zh-hant/simplified-only.txt"), encoding: .utf8)
    let forbiddenCharacters = Set(forbidden.trimmingCharacters(in: .newlines))
    for path in paths {
      let data = try Data(contentsOf: root.appending(path: "\(path)/Localizable.xcstrings"))
      let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      let strings = try #require(catalog["strings"] as? [String: Any])
      for (key, value) in strings {
        let entry = try #require(value as? [String: Any])
        let locales = try #require(entry["localizations"] as? [String: Any])
        let source = try #require(locales["zh-Hans"] as? [String: Any])
        let target = try #require(locales["zh-Hant"] as? [String: Any], "\(path): \(key)")
        try compare(source, target, forbidden: forbiddenCharacters, context: "\(path): \(key)")
      }
    }
  }

  private func compare(
    _ source: [String: Any], _ target: [String: Any], forbidden: Set<Character>, context: String
  ) throws {
    #expect(Set(source.keys) == Set(target.keys), "\(context)")
    for (key, value) in source {
      if let nested = value as? [String: Any] {
        try compare(
          nested, #require(target[key] as? [String: Any]), forbidden: forbidden, context: context)
      } else if key == "value", let text = value as? String {
        let translated = try #require(target[key] as? String)
        let pattern =
          #"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?"#
          + #"(?:hh|ll|[hljztL])?[@diuoxXfFeEgGaAcCsSpn%]|\{\{?[^{}]+\}?\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        func placeholders(_ string: String) -> [String] {
          regex.matches(in: string, range: NSRange(string.startIndex..., in: string)).map {
            (string as NSString).substring(with: $0.range)
          }
        }
        #expect(placeholders(text) == placeholders(translated), "\(context)")
        #expect(
          Set(translated).isDisjoint(with: forbidden),
          "\(context): \(translated)")
      } else {
        #expect(String(describing: value) == String(describing: target[key] ?? ""), "\(context)")
      }
    }
  }
}
