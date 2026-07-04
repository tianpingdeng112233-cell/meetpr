import CoreModels
import Foundation

/// Name matching for exercise search boxes (coach accessory search and the
/// student-side picker, spec 045).
///
/// 杆 and 杠 are used interchangeably across the catalog (e.g. the 高杠位深蹲 /
/// 低杠位深蹲 spelling vs the 安全杆 spelling) and in coach shorthand, so a search
/// for either character must match both. We fold 杆 → 杠 on both the query and the
/// candidate name before the locale-aware contains check.
/// (David 2026-06-24 — 吕子豪 / 邓天平 plan coverage audit.)
public enum ExerciseSearch {
  /// Folds the interchangeable 杆 / 杠 characters to a single canonical form.
  public static func fold(_ text: String) -> String {
    text.replacing("杆", with: "杠")
  }

  /// Whether `exercise` matches `query` by Chinese or English name — tolerant of
  /// the 杆 / 杠 spelling difference and of locale (case, width, diacritics).
  public static func matches(_ exercise: Exercise, query: String) -> Bool {
    let folded = fold(query)
    if fold(exercise.name).localizedStandardContains(folded) {
      return true
    }
    if let nameEn = exercise.nameEn {
      return fold(nameEn).localizedStandardContains(folded)
    }
    return false
  }
}
