import CoreModels
import Foundation

/// CoachKit 各 feature 共用的本地化取值口。
///
/// 三个 feature 的 strings 文件各自复制一份 `localized`/`replacing` 之后,
/// 既是平行工具也容易漂移(review-loop 2026-07-30)。统一放这里,
/// 各 feature 只负责声明自己的 key。
enum CoachLocalization {
  static func localized(
    _ key: String.LocalizationValue,
    locale: Locale = .current,
    bundle: Bundle = .module
  ) -> String {
    String(localized: key, bundle: bundle, locale: locale)
  }

  static func replacing(
    _ key: String.LocalizationValue,
    values: [String: String],
    locale: Locale = .current
  ) -> String {
    values.reduce(localized(key, locale: locale)) { partial, entry in
      partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
    }
  }

  /// Exercise names are catalog data, not translatable UI copy. English
  /// presentation always uses the catalog's canonical `nameEn` value.
  static func exerciseName(_ exercise: Exercise, locale: Locale = .current) -> String {
    guard locale.language.languageCode == .english else { return exercise.name }
    // A missing nameEn is deliberate for coach-authored exercises: their
    // Chinese canonical name is user content and remains the English fallback.
    return exercise.nameEn ?? exercise.name
  }

  static func exerciseName(_ canonicalName: String, locale: Locale = .current) -> String {
    guard locale.language.languageCode == .english else { return canonicalName }
    // Catalog lookup omits coach-authored exercises without nameEn, so retain
    // their user-provided Chinese canonical name instead of hiding the value.
    return exerciseEnglishNames[canonicalName] ?? canonicalName
  }

  private static let exerciseEnglishNames: [String: String] = Dictionary(
    uniqueKeysWithValues: (InMemoryPlanRepository.syntheticCompetitionLifts()
      + InMemoryPlanRepository.loadBundledCatalogV2())
      .compactMap { exercise in
        exercise.nameEn.map { (exercise.name, $0) }
      }
  )
}
