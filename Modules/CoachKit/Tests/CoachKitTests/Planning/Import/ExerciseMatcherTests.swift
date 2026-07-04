import CatalogKit
import CoreModels
import Foundation
import Testing

@testable import CoachKit

// spec 043 §E4 — exact 折叠 binding + 杆/杠 tolerance + clean miss.

private func exercise(_ name: String, family: LiftFamily? = nil) -> Exercise {
  Exercise(
    id: UUID(),
    name: name,
    exerciseType: family == nil ? .accessory : .mainLift,
    mainLiftFamily: family,
    isCompetitionLift: family != nil,
    muscleGroups: [],
    equipment: [],
    movementPattern: [],
    createdAt: Date(timeIntervalSince1970: 0)
  )
}

@Test func exactFoldBindsLowBarSquat() {
  let catalog = [exercise("低杠深蹲", family: .squat), exercise("常规硬拉", family: .deadlift)]
  let match = ExerciseMatcher.exactMatch(rawName: "低杆深蹲", catalog: catalog)  // 杆 folds to 杠
  #expect(match?.name == "低杠深蹲")
  #expect(match?.mainLiftFamily == .squat)
}

@Test func barCharacterFoldsBothWays() {
  let catalog = [exercise("安全杆卧推")]
  #expect(ExerciseMatcher.exactMatch(rawName: "安全杠卧推", catalog: catalog)?.name == "安全杆卧推")
}

@Test func unmatchedNameDoesNotBind() {
  let catalog = [exercise("常规硬拉", family: .deadlift)]
  #expect(ExerciseMatcher.exactMatch(rawName: "噩梦硬拉", catalog: catalog) == nil)
}

// spec 043 §E — layer ② alias table never overrides a library exact-name hit.
@Test func exactMatchWinsOverAlias() {
  let exact = exercise("卧推")  // library happens to carry the bare 裸名
  let aliasTarget = exercise("杠铃卧推")
  let catalog = [exact, aliasTarget]
  let aliases = ExerciseAliasTable(
    version: 1,
    aliases: [ExerciseAlias(alias: "卧推", canonical: "杠铃卧推")]
  )
  let match = ExerciseMatcher.resolve(rawName: "卧推", catalog: catalog, aliases: aliases)
  #expect(match?.id == exact.id)
}

@Test func aliasBindsWhenNoExactMatch() {
  let target = exercise("杠铃卧推")
  let catalog = [target, exercise("常规硬拉", family: .deadlift)]
  let aliases = ExerciseAliasTable(
    version: 1,
    aliases: [ExerciseAlias(alias: "卧推", canonical: "杠铃卧推")]
  )
  let match = ExerciseMatcher.resolve(rawName: "卧推", catalog: catalog, aliases: aliases)
  #expect(match?.id == target.id)
}
