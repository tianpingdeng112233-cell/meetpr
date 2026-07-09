import CoreModels
import Foundation

/// The bundled exercise catalog (spec 022 v2 import, deduped by #209),
/// shared by coach planning and the student-side exercise picker (spec 045).
/// Lifted out of CoachKit so StudentKit can depend on it without inheriting
/// planning machinery.
public enum ExerciseCatalog {
  /// Decodes the bundled `exercise-catalog-v2.json`. Synthetic competition
  /// lifts are CoachKit's planning concern and are not part of this list.
  public static func loadBundled() -> [Exercise] {
    guard
      let url = Bundle.module.url(
        forResource: "exercise-catalog-v2",
        withExtension: "json"
      )
    else {
      assertionFailure("Bundled catalog v2 missing. Check Package.swift resources declaration.")
      return []
    }

    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode([Exercise].self, from: data)
    } catch {
      assertionFailure("Bundled catalog v2 decode failed: \(error)")
      return []
    }
  }
}
