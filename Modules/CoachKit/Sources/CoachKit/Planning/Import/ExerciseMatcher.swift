import CoreModels
import Foundation

// Binds a parsed `rawName` to the catalog (spec 043 §E). An exact 折叠相等 match
// (杆/杠-folded string equality) auto-binds; otherwise `ExerciseSearch.matches`
// gives folded-substring candidates and the coach picks one or skips. V1 never
// creates a custom exercise.

enum ExerciseMatcher {
  /// The single catalog exercise whose (folded) name equals `rawName`, if any.
  static func exactMatch(rawName: String, catalog: [Exercise]) -> Exercise? {
    let needle = foldKey(rawName)
    guard !needle.isEmpty else { return nil }
    return catalog.first { candidate in
      if foldKey(candidate.name) == needle { return true }
      if let nameEn = candidate.nameEn { return foldKey(nameEn) == needle }
      return false
    }
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
