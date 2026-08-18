import Foundation
import Testing

enum LocalizationCatalogTestSupport {
  static func simplifiedChineseSource(_ rendered: String, key: String) throws -> String {
    guard rendered == key else { return rendered }
    let catalog = loadCatalog()
    let strings = try #require(catalog["strings"] as? [String: Any])
    let entry = try #require(strings[key] as? [String: Any], "Missing catalog key: \(key)")
    let localizations = try #require(entry["localizations"] as? [String: Any])
    let chinese = try #require(localizations["zh-Hans"] as? [String: Any])
    let stringUnit = try #require(chinese["stringUnit"] as? [String: Any])
    return try #require(stringUnit["value"] as? String)
  }

  private static func loadCatalog() -> [String: Any] {
    let packageRoot =
      URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let catalogURL = packageRoot.appending(
      path: "Sources/AppShell/Resources/Localizable.xcstrings"
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
