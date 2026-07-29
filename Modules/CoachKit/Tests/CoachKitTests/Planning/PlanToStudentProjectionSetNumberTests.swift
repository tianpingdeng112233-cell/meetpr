import CoreModels
import Foundation
import Testing

@testable import CoachKit

// Set-number projection hygiene (spec 029 C0): corrupt planning rows must be dropped, never
// clamped — a clamp folds [0, 1] onto execution index 0 and the (planExerciseID, setIndex)
// log key would make two cards share one log.

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionDropsCorruptZeroSetNumberAndKeepsLegalSetsUncollided() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60),
    dayID: day.id,
    exerciseID: ProjFixtures.squatID,
    isMain: true,
    sortOrder: 0
  )
  // A clamp here would fold [0, 1] into [0, 0] and the execution layer, which keys logs by
  // (planExerciseID, setIndex), would share one log between two cards. The corrupt set must
  // be dropped, and the legal set must keep its own identity.
  let dirtySet = ProjFixtures.set(exID: exercise.id, number: 0, value: Decimal(100))
  let legalSet = ProjFixtures.set(exID: exercise.id, number: 1, value: Decimal(120))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(),
    days: [day],
    exercises: [exercise],
    sets: [dirtySet, legalSet],
    catalog: ProjFixtures.catalog(),
    weekIndex: 1
  )

  let sets = try #require(view.days.first?.exercises.first?.prescribedSets)
  #expect(sets.count == 1)
  #expect(sets.first?.setIndex == 0)
  #expect(sets.first?.weightKg == Decimal(120))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionYieldsNoSetsWhenEveryPlanSetIsCorrupt() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60),
    dayID: day.id,
    exerciseID: ProjFixtures.squatID,
    isMain: true,
    sortOrder: 0
  )
  let dirtySet = ProjFixtures.set(exID: exercise.id, number: 0, value: Decimal(100))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(),
    days: [day],
    exercises: [exercise],
    sets: [dirtySet],
    catalog: ProjFixtures.catalog(),
    weekIndex: 1
  )

  #expect(view.days.first?.exercises.first?.prescribedSets.isEmpty == true)
}
