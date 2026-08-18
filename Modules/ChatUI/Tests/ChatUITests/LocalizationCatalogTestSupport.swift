import Foundation
import Testing

enum LocalizationCatalogTestSupport {
  static func value(
    _ key: String,
    locale: String,
    arguments: [String] = []
  ) throws -> String {
    let catalog = loadCatalog()
    let strings = try #require(catalog["strings"] as? [String: Any])
    let entry = try #require(strings[key] as? [String: Any], "Missing catalog key: \(key)")
    let localizations = try #require(entry["localizations"] as? [String: Any])
    let localization = try #require(
      localizations[locale] as? [String: Any],
      "Missing \(locale) localization for: \(key)"
    )
    let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
    var rendered = try #require(stringUnit["value"] as? String)
    for argument in arguments {
      let range = try #require(rendered.range(of: "%@"))
      rendered.replaceSubrange(range, with: argument)
    }
    return rendered
  }

  private static func loadCatalog() -> [String: Any] {
    let repositoryRoot =
      URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let catalogURL = repositoryRoot.appending(
      path: "Sources/ChatUI/Resources/Localizable.xcstrings"
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
