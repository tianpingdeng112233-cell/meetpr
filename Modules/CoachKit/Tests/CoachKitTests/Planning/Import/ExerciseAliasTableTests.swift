import CoreModels
import Foundation
import Testing

@testable import CoachKit

// spec 043 §动作别名表附录 — the bundled alias seed resolves against the real
// 完整动作集 (synthetic 比赛式X + bundled catalog v2), with a load-time guardrail
// so a catalog rename can't leave any canonical dangling.

@available(iOS 17.0, macOS 14.0, *)
private func fullCatalog() -> [Exercise] {
  InMemoryPlanRepository.syntheticCompetitionLifts()
    + InMemoryPlanRepository.loadBundledCatalogV2()
}

@available(iOS 17.0, macOS 14.0, *)
@Test func bundledAliasSeedHasTwentySixEntries() {
  let table = ExerciseAliasTable.bundled()
  #expect(table.version == 1)
  #expect(table.aliases.count == 26)
}

// Guardrail: every canonical must fold-resolve to exactly one exercise in the full
// set. A miss or an ambiguous hit turns this test red — authoritative source, not
// a runtime best-effort .first().
@available(iOS 17.0, macOS 14.0, *)
@Test func everyAliasCanonicalResolvesUniquely() {
  let catalog = fullCatalog()
  for alias in ExerciseAliasTable.bundled().aliases {
    let key = ExerciseSearch.fold(alias.canonical)
    let hits = catalog.filter { ExerciseSearch.fold($0.name) == key }
    #expect(
      hits.count == 1,
      "canonical \(alias.canonical) (alias \(alias.alias)) resolved to \(hits.count) exercises"
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Test(arguments: [
  ("低杆深蹲", "低杠位深蹲"),  // 位 missing + 杆/杠 fold
  ("卧推", "杠铃卧推"),  // 裸名
  ("传统硬拉", "比赛式传统硬拉"),  // → synthetic competition lift
  ("相扑硬拉", "比赛式相扑硬拉"),  // → synthetic competition lift
  ("窄推", "窄握卧推"),  // 缺字
  ("长暂停卧推", "暂停卧推"),  // 词序 / 修饰
])
func aliasSeedRowsBindToCanonical(rawName: String, canonical: String) {
  let catalog = fullCatalog()
  let aliases = ExerciseAliasTable.bundled()
  let match = ExerciseMatcher.resolve(rawName: rawName, catalog: catalog, aliases: aliases)
  #expect(match?.name == canonical)
}

@available(iOS 17.0, macOS 14.0, *)
@Test(arguments: ["离心卧推", "弹力带窄推", "安全杠节奏深蹲"])
func newCatalogExercisesBindExactly(name: String) {
  let match = ExerciseMatcher.resolve(
    rawName: name,
    catalog: fullCatalog(),
    aliases: ExerciseAliasTable.bundled()
  )
  #expect(match?.name == name)
}

// A genuinely unknown name binds to nothing (①②) yet still surfaces folded-substring
// candidates (③) for the coach to pick from.
@available(iOS 17.0, macOS 14.0, *)
@Test func unmatchedNameFallsThroughToCandidates() {
  let catalog = fullCatalog()
  let aliases = ExerciseAliasTable.bundled()
  let rawName = "罗马尼亚"  // not exact, not an alias key, but a substring of several names
  #expect(ExerciseMatcher.resolve(rawName: rawName, catalog: catalog, aliases: aliases) == nil)
  #expect(!ExerciseMatcher.candidates(rawName: rawName, catalog: catalog).isEmpty)
}
