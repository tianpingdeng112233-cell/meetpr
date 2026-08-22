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

// Golden matrix mirroring StudentPlanIntensityProjectionTests so the two
// duplicated projections cannot drift (round-1 review nit): six forms, sparse,
// dual anchor and both legacy shapes must project identically here.
private func goldenMatrixSets(exerciseID: UUID) -> [PlanSet] {
  let timestamp = Date(timeIntervalSince1970: 1_900_000_000)
  func matrixSet(
    _ number: Int,
    mode: IntensityMode,
    value: Decimal,
    loadMode: PlanLoadMode? = nil,
    targetPct: Decimal? = nil,
    targetRPE: Decimal? = nil,
    rirTarget: Int? = nil,
    rpeLow: Decimal? = nil,
    rpeHigh: Decimal? = nil,
    weightLow: Decimal? = nil,
    weightHigh: Decimal? = nil,
    targetWeight: Decimal? = nil
  ) -> PlanSet {
    PlanSet(
      id: ProjFixtures.uuid(UInt8(90 + number)),
      planExerciseID: exerciseID,
      setNumber: number,
      targetReps: 5,
      intensityMode: mode,
      targetValue: value,
      loadMode: loadMode,
      targetPct: targetPct,
      targetRPE: targetRPE,
      rirTarget: rirTarget,
      rpeLow: rpeLow,
      rpeHigh: rpeHigh,
      weightLow: weightLow,
      weightHigh: weightHigh,
      targetWeight: targetWeight,
      setType: .working,
      restSeconds: nil,
      createdAt: timestamp
    )
  }
  return [
    matrixSet(1, mode: .rpe, value: 7.1, loadMode: .percentage, targetPct: 72.5),
    matrixSet(2, mode: .weight, value: 999, loadMode: .rpe, targetRPE: 8.5),
    matrixSet(3, mode: .rpe, value: 8, loadMode: .rir, rirTarget: 2),
    matrixSet(
      4, mode: .weight, value: 165, loadMode: .weightRange, weightLow: 165, weightHigh: 175),
    matrixSet(5, mode: .rpe, value: 8, loadMode: .rpeRange, rpeLow: 9, rpeHigh: 9.5),
    matrixSet(6, mode: .weight, value: 999, loadMode: .fixedWeight, targetWeight: 170),
    matrixSet(7, mode: .weight, value: 170, loadMode: .rpe, targetRPE: 9, targetWeight: 170),
    matrixSet(8, mode: .weight, value: 150, loadMode: .percentage, targetWeight: 150),
    matrixSet(9, mode: .rpe, value: 8),
    matrixSet(10, mode: .weight, value: 140),
  ]
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionMatchesStudentGoldenMatrixForAllForms() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(70), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(80), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let sets = goldenMatrixSets(exerciseID: exercise.id)

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [exercise], sets: sets,
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )
  let projected = try #require(view.days.first?.exercises.first?.prescribedSets)

  #expect(projected.count == 10)
  #expect(projected[0].weightKg == nil)
  #expect(projected[0].intensity == .percentage(72.5))
  #expect(projected[0].loadMode == .percentage)
  #expect(projected[1].intensity == .rpe(8.5))
  #expect(projected[2].intensity == .rir(2))
  #expect(projected[3].intensity == .weightRange(165, 175))
  #expect(projected[4].intensity == .rpeRange(9, 9.5))
  #expect(projected[5].weightKg == 170)
  #expect(projected[5].intensity == nil)
  #expect(projected[5].loadMode == .fixedWeight)
  #expect(projected[6].weightKg == 170)
  #expect(projected[6].intensity == .rpe(9))
  #expect(projected[7].weightKg == 150)
  #expect(projected[7].intensity == nil)
  #expect(projected[7].loadMode == .percentage)
  #expect(projected[8].weightKg == nil)
  #expect(projected[8].rpe == 8)
  #expect(projected[8].isLegacyPrescription)
  #expect(projected[9].weightKg == 140)
  #expect(projected[9].intensity == nil)
  #expect(projected[9].isLegacyPrescription)
}
