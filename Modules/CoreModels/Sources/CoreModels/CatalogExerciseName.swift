import Foundation

/// Presentation-only names from the bundled canonical catalog; never rewrites stored data.
public enum CatalogExerciseName {
  public static func display(_ exercise: Exercise, locale: Locale = .current) -> String {
    guard exercise.createdByCoachID == nil else { return exercise.name }
    return display(exercise.name, isCatalog: true, locale: locale)
  }

  public static func display(
    _ canonicalName: String, isCatalog: Bool, locale: Locale = .current
  ) -> String {
    guard isCatalog else { return canonicalName }
    guard InterfaceLanguage(locale: locale) == .traditionalChinese else { return canonicalName }
    return traditionalNames[canonicalName] ?? canonicalName
  }

  private static let traditionalNames: [String: String] = {
    guard let url = Bundle.module.url(forResource: "exercise-names-zh-Hant", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let names = try? JSONDecoder().decode([String: String].self, from: data)
    else { return [:] }
    return names
  }()
}
