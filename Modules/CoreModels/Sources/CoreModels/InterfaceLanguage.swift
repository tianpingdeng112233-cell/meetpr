import Foundation

/// The language negotiated by the app bundle, shared by UI adapters and API requests.
public enum InterfaceLanguage: String, Sendable {
  case simplifiedChinese = "zh-Hans"
  case traditionalChinese = "zh-Hant"
  case english = "en"

  public static var current: Self {
    Self(localization: Bundle.main.preferredLocalizations.first ?? "zh-Hans")
  }

  public init(localization: String) {
    let tag = localization.replacing("_", with: "-").lowercased()
    guard tag == "zh" || tag.hasPrefix("zh-") else {
      self = .english
      return
    }
    let parts = tag.split(separator: "-")
    if parts.contains("hans") {
      self = .simplifiedChinese
      return
    }
    self =
      tag.hasPrefix("zh-hant") || parts.contains(where: { ["tw", "hk", "mo"].contains($0) })
      ? .traditionalChinese : .simplifiedChinese
  }

  public init(locale: Locale) {
    self.init(localization: locale.identifier)
  }
}
