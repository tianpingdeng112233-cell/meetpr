import CoreModels
import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionUsesCanonicalLoadFieldsInsteadOfLegacyProjection() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let pct = ProjFixtures.set(
    exID: exercise.id,
    number: 1,
    mode: .rpe,
    value: 7.1,
    loadMode: .percentage,
    targetPct: 72.5
  )
  let dual = ProjFixtures.set(
    exID: exercise.id,
    number: 2,
    mode: .weight,
    value: 999,
    loadMode: .rpe,
    targetRPE: 9,
    targetWeight: 170
  )

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [exercise], sets: [pct, dual],
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )
  let sets = try #require(view.days.first?.exercises.first?.prescribedSets)

  #expect(sets[0].weightKg == nil)
  #expect(sets[0].intensity == .percentage(72.5))
  #expect(sets[0].rpe == nil)
  #expect(sets[0].restSeconds == 180)
  #expect(sets[1].weightKg == 170)
  #expect(sets[1].intensity == .rpe(9))
  #expect(sets[1].restSeconds == 240)
}
