import Foundation
import Testing

enum LocalizationCatalogTestSupport {
  static func simplifiedChinese(
    _ rendered: String,
    key: String,
    arguments: [String] = []
  ) throws -> String {
    guard rendered.hasPrefix("designSystem.") else { return rendered }
    return try value(key, locale: "zh-Hans", arguments: arguments)
  }

  static func value(
    _ key: String,
    locale: String,
    arguments: [String] = []
  ) throws -> String {
    let catalog = loadCatalog()
    let strings = try #require(catalog["strings"] as? [String: Any])
    let entry = try #require(strings[key] as? [String: Any], "Missing catalog key: \(key)")
    let localizations = try #require(entry["localizations"] as? [String: Any])
    let localization = try #require(localizations[locale] as? [String: Any])
    let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
    var rendered = try #require(stringUnit["value"] as? String)
    for argument in arguments {
      let range = try #require(rendered.range(of: "%@"))
      rendered.replaceSubrange(range, with: argument)
    }
    return rendered
  }

  private static func loadCatalog() -> [String: Any] {
    let packageRoot =
      URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let catalogURL = packageRoot.appending(
      path: "Sources/DesignSystem/Resources/Localizable.xcstrings"
    )
    guard
      let data = try? Data(contentsOf: catalogURL),
      let catalog = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return [:]
    }
    return catalog
  }
}
