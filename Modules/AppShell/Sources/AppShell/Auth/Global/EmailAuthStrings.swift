import Foundation
import Networking

/// CN follows the device language; Global keeps its existing English auth copy.
enum EmailAuthStrings {
  static func text(_ key: String, track: MeetPRBuildTrack) -> String {
    if track == .china { return String(localized: String.LocalizationValue(key), bundle: .module) }
    if let englishBundle {
      return englishBundle.localizedString(forKey: key, value: nil, table: nil)
    }
    // Command-line SwiftPM copies catalogs without compiling their .lproj resources.
    return uncompiledEnglish[key] ?? key
  }

  private static let englishBundle: Bundle? = {
    guard let path = Bundle.module.path(forResource: "en", ofType: "lproj") else { return nil }
    return Bundle(path: path)
  }()

  private static let uncompiledEnglish: [String: String] = {
    guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
      let data = try? Data(contentsOf: url),
      let catalog = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let strings = catalog["strings"] as? [String: [String: Any]]
    else { return [:] }
    return strings.compactMapValues { entry in
      let localizations = entry["localizations"] as? [String: [String: Any]]
      let unit = localizations?["en"]?["stringUnit"] as? [String: String]
      return unit?["value"]
    }
  }()
}
