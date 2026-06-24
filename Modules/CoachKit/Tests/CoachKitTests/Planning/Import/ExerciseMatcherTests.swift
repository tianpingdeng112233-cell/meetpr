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
