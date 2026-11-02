import CoreModels
import Foundation

func intensityProjectionSets(planExerciseID: UUID, timestamp: Date) -> [PlanSet] {
  [
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 1,
      legacyMode: .rpe, legacyValue: 7.1, loadMode: .percentage, targetPct: 72.5,
      percentageAnchor: .e1RM),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 2,
      legacyMode: .weight, legacyValue: 999, loadMode: .rpe, targetRPE: 8.5),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 3,
      legacyMode: .rpe, legacyValue: 8, loadMode: .rir, rirTarget: 2),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 4,
      legacyMode: .weight, legacyValue: 165, loadMode: .weightRange,
      weightLow: 165, weightHigh: 175),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 5,
      legacyMode: .rpe, legacyValue: 8, loadMode: .rpeRange,
      rpeLow: 9, rpeHigh: 9.5),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 6,
      legacyMode: .weight, legacyValue: 999, loadMode: .fixedWeight,
      targetWeight: 170),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 7,
      legacyMode: .weight, legacyValue: 170, loadMode: .rpe,
      targetRPE: 9, targetWeight: 170),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 8,
      legacyMode: .weight, legacyValue: 150, loadMode: .percentage,
      targetWeight: 150),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 9,
      legacyMode: .rpe, legacyValue: 8),
    intensityProjectionSet(
      exerciseID: planExerciseID, timestamp: timestamp, number: 10,
      legacyMode: .weight, legacyValue: 140),
  ]
}

func intensityProjectionSet(
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
  targetWeight: Decimal? = nil,
  coachNote: String? = nil
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
    coachNote: coachNote,
    createdAt: timestamp
  )
}
