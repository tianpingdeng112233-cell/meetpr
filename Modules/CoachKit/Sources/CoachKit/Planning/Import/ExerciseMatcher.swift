import CoreModels
import Foundation

// Binds a parsed `rawName` to the catalog (spec 043 §E). The four layers, in order:
// ① exact 折叠相等 match (杆/杠-folded string equality) auto-binds; ② else the alias
// table (folded alias → canonical → catalog) auto-binds; ③ else `ExerciseSearch.matches`
// gives folded-substring candidates and the coach picks one; ④ else skip. An alias
// never overrides a library exact-name hit. V1 never creates a custom exercise.

enum ExerciseMatcher {
  /// Layers ①→② combined: an exact catalog match wins; otherwise the alias table.
  /// `nil` when neither binds — the coach picks from `candidates` (③) or skips (④).
  static func resolve(
    rawName: String,
    catalog: [Exercise],
    aliases: ExerciseAliasTable
  ) -> Exercise? {
    exactMatch(rawName: rawName, catalog: catalog)
      ?? aliasMatch(rawName: rawName, catalog: catalog, aliases: aliases)
  }

  /// Layer ①: the single catalog exercise whose (folded) name equals `rawName`, if any.
  static func exactMatch(rawName: String, catalog: [Exercise]) -> Exercise? {
    let needle = foldKey(rawName)
    guard !needle.isEmpty else { return nil }
    return catalog.first { candidate in
      if foldKey(candidate.name) == needle { return true }
      if let nameEn = candidate.nameEn { return foldKey(nameEn) == needle }
      return false
    }
  }

  /// Layer ②: the catalog exercise an alias points to, when `rawName` folds equal to
  /// an alias key. The canonical is matched by folded `name` only (规范名 is Chinese).
  /// Never consulted before `exactMatch`, so aliases can't shadow exact library names.
  static func aliasMatch(
    rawName: String,
    catalog: [Exercise],
    aliases: ExerciseAliasTable
  ) -> Exercise? {
    let needle = foldKey(rawName)
    guard !needle.isEmpty else { return nil }
    guard
      let canonical = aliases.aliases.first(where: { foldKey($0.alias) == needle })?.canonical
    else { return nil }
    let canonicalKey = foldKey(canonical)
    return catalog.first { foldKey($0.name) == canonicalKey }
  }

  /// Ranked candidates for a name that didn't bind exactly. Exact-fold matches
  /// first (defensive), then folded-substring matches, locale-sorted.
  static func candidates(rawName: String, catalog: [Exercise], limit: Int = 12) -> [Exercise] {
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    let matches = catalog.filter { ExerciseSearch.matches($0, query: trimmed) }
    let sorted = matches.sorted { lhs, rhs in
      lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
    return Array(sorted.prefix(limit))
  }

  private static func foldKey(_ text: String) -> String {
    ExerciseSearch.fold(text.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}
