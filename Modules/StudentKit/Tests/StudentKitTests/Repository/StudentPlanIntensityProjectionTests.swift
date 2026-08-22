import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

@Test func studentProjectionUsesCanonicalIntensityFieldsAndIgnoresLegacyProjection() throws {
  let fixture = intensityProjectionFixture()

  let view = StudentPlanProjection.project(
    tree: fixture.tree,
    catalog: [fixture.catalogExercise],
    weekIndex: 1
  )
  let sets = try #require(view.days.first?.exercises.first?.prescribedSets)

  #expect(sets.count == 10)
  #expect(sets[0].weightKg == nil)
  #expect(sets[0].intensity == .percentage(72.5))
  #expect(sets[0].percentageAnchor == .e1RM)
  #expect(sets[0].rpe == nil)
  #expect(sets[0].restSeconds == 180)
  #expect(sets[1].intensity == .rpe(8.5))
  #expect(sets[2].intensity == .rir(2))
  #expect(sets[3].intensity == .weightRange(165, 175))
  #expect(sets[4].intensity == .rpeRange(9, 9.5))
  #expect(sets[4].restSeconds == 240)
  #expect(sets[5].weightKg == 170)
  #expect(sets[5].intensity == nil)
  #expect(sets[5].restSeconds == 180)
  #expect(sets[6].weightKg == 170)
  #expect(sets[6].intensity == .rpe(9))
  #expect(sets[7].weightKg == 150)
  #expect(sets[7].intensity == nil)
  #expect(sets[8].weightKg == nil)
  #expect(sets[8].intensity == .rpe(8))
  #expect(sets[8].restSeconds == nil)
  #expect(sets[9].weightKg == 140)
  #expect(sets[9].intensity == nil)
  #expect(sets[0].loadMode == .percentage)
  #expect(sets[7].loadMode == .percentage)
  #expect(!sets[7].isLegacyPrescription)
  #expect(sets[8].isLegacyPrescription)
  #expect(sets[9].isLegacyPrescription)
}

@Test func scheduledDateKeepsLegacyStartDateWhenAnchorIsNil() {
  let startDate = utcDate(year: 2026, month: 8, day: 14)
  let day = projectionDay(week: 1, dayOfWeek: 1)

  let scheduled = StudentPlanProjection.scheduledDate(
    for: day,
    startDate: startDate,
    anchorWeekday: nil
  )

  #expect(scheduled == startDate)
}

@Test func scheduledDateIncludesStartDateWhenItMatchesAnchor() {
  let wednesday = utcDate(year: 2026, month: 8, day: 12)
  let day = projectionDay(week: 1, dayOfWeek: 1)

  let scheduled = StudentPlanProjection.scheduledDate(
    for: day,
    startDate: wednesday,
    anchorWeekday: 3
  )

  #expect(scheduled == wednesday)
}

@Test func scheduledDateMovesToNextAnchorAndAppliesCrossWeekOffset() {
  let friday = utcDate(year: 2026, month: 8, day: 14)
  let weekTwoDayThree = projectionDay(week: 2, dayOfWeek: 3)

  let scheduled = StudentPlanProjection.scheduledDate(
    for: weekTwoDayThree,
    startDate: friday,
    anchorWeekday: 1
  )

  #expect(scheduled == utcDate(year: 2026, month: 8, day: 26))
}

private func intensityProjectionFixture() -> (
  tree: TrainingPlanTree, catalogExercise: Exercise
) {
  let timestamp = utcDate(year: 2026, month: 8, day: 12)
  let planID = UUID()
  let dayID = UUID()
  let planExerciseID = UUID()
  let catalogID = UUID()
  let plan = projectionPlan(id: planID, timestamp: timestamp)
  let day = PlanDay(
    id: dayID, planID: planID, dayOfWeek: 1, weekNumber: 1, sortOrder: 0)
  let exercise = PlanExercise(
    id: planExerciseID,
    planDayID: dayID,
    exerciseID: catalogID,
    isMainLift: true,
    sortOrder: 0
  )
  let sets = projectionSets(planExerciseID: planExerciseID, timestamp: timestamp)
  let catalogExercise = projectionCatalogExercise(id: catalogID, timestamp: timestamp)
  return (
    TrainingPlanTree(plan: plan, days: [day], exercises: [exercise], sets: sets),
    catalogExercise
  )
}

private func projectionPlan(id: UUID, timestamp: Date) -> TrainingPlan {
  TrainingPlan(
    id: id,
    traineeID: UUID(),
    name: "六形式",
    startDate: timestamp,
    endDate: timestamp.addingTimeInterval(2_419_200),
    planWeeks: 4,
    source: .coach,
    status: .published,
    createdAt: timestamp,
    updatedAt: timestamp
  )
}

private func projectionCatalogExercise(id: UUID, timestamp: Date) -> Exercise {
  Exercise(
    id: id,
    name: "深蹲",
    exerciseType: .mainLift,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    createdAt: timestamp
  )
}

private func projectionSets(planExerciseID: UUID, timestamp: Date) -> [PlanSet] {
  [
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 1,
      legacyMode: .rpe, legacyValue: 7.1, loadMode: .percentage, targetPct: 72.5,
      percentageAnchor: .e1RM),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 2,
      legacyMode: .weight, legacyValue: 999, loadMode: .rpe, targetRPE: 8.5),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 3,
      legacyMode: .rpe, legacyValue: 8, loadMode: .rir, rirTarget: 2),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 4,
      legacyMode: .weight, legacyValue: 165, loadMode: .weightRange,
      weightLow: 165, weightHigh: 175),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 5,
      legacyMode: .rpe, legacyValue: 8, loadMode: .rpeRange,
      rpeLow: 9, rpeHigh: 9.5),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 6,
      legacyMode: .weight, legacyValue: 999, loadMode: .fixedWeight,
      targetWeight: 170),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 7,
      legacyMode: .weight, legacyValue: 170, loadMode: .rpe,
      targetRPE: 9, targetWeight: 170),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 8,
      legacyMode: .weight, legacyValue: 150, loadMode: .percentage,
      targetWeight: 150),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 9,
      legacyMode: .rpe, legacyValue: 8),
    projectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 10,
      legacyMode: .weight, legacyValue: 140),
  ]
}

private func projectionSet(
  exerciseID: UUID,
  timestamp: Date,
  number: Int,
  legacyMode: IntensityMode,
  legacyValue: Decimal,
  loadMode: PlanLoadMode? = nil,
  targetPct: Decimal? = nil,
  percentageAnchor: PercentageAnchor? = nil,
  targetRPE: Decimal? = nil,
  rirTarget: Int? = nil,
  rpeLow: Decimal? = nil,
  rpeHigh: Decimal? = nil,
  weightLow: Decimal? = nil,
  weightHigh: Decimal? = nil,
  targetWeight: Decimal? = nil
) -> PlanSet {
  PlanSet(
    id: UUID(),
    planExerciseID: exerciseID,
    setNumber: number,
    targetReps: 5,
    intensityMode: legacyMode,
    targetValue: legacyValue,
    loadMode: loadMode,
    targetPct: targetPct,
    percentageAnchor: percentageAnchor,
    targetRPE: targetRPE,
    rirTarget: rirTarget,
    rpeLow: rpeLow,
    rpeHigh: rpeHigh,
    weightLow: weightLow,
    weightHigh: weightHigh,
    targetWeight: targetWeight,
    setType: .working,
    createdAt: timestamp
  )
}

private func projectionDay(week: Int, dayOfWeek: Int) -> PlanDay {
  PlanDay(
    id: UUID(),
    planID: UUID(),
    dayOfWeek: dayOfWeek,
    weekNumber: week,
    sortOrder: 0
  )
}

private func utcDate(year: Int, month: Int, day: Int) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
}
