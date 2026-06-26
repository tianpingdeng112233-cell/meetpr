import Foundation

// The coach-shorthand → 规范名 alias table (spec 043 §动作别名表附录). This is the
// second matching layer: consulted only after an exact 折叠相等 catalog match misses,
// so an alias never overrides a library exact-name hit. Both the alias key and the
// canonical are 杆/杠-folded before comparison; each canonical resolves against the
// 完整动作集 (synthetic 比赛式X + bundled catalog) and must fold to a unique name —
// enforced by a load-time guardrail test so a catalog rename can't leave it dangling.

struct ExerciseAlias: Decodable, Equatable {
  let alias: String
  let canonical: String
}

struct ExerciseAliasTable: Decodable {
  let version: Int
  let aliases: [ExerciseAlias]

  /// The bundled, hand-maintained V1 seed table.
  static func bundled() -> ExerciseAliasTable {
    guard let url = Bundle.module.url(forResource: "exercise-aliases", withExtension: "json") else {
      assertionFailure("Bundled alias table missing. Check Package.swift resources declaration.")
      return ExerciseAliasTable(version: 0, aliases: [])
    }
    do {
      return try JSONDecoder().decode(ExerciseAliasTable.self, from: Data(contentsOf: url))
    } catch {
      assertionFailure("Bundled alias table decode failed: \(error)")
      return ExerciseAliasTable(version: 0, aliases: [])
    }
  }
}
