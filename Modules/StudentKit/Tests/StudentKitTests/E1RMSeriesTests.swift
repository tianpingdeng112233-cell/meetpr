import CoreModels
import Foundation
import Testing

@testable import StudentKit

private let seriesStudentID = UUID()
private let seriesExerciseID = UUID()
private let seriesNow = Date(timeIntervalSince1970: 1_782_000_000)

private func seriesPoint(
  daysAgo: Int,
  e1RM: Double,
  reps: Int = 5,
  rpe: Double? = 8,
  confidence: E1RMConfidence = .normal
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: seriesStudentID,
    exerciseId: seriesExerciseID,
    setLogId: UUID(),
    computedAt: seriesNow.addingTimeInterval(TimeInterval(-daysAgo) * 86_400),
    e1RMKg: e1RM,
    sourceWeightKg: e1RM * 0.85,
    sourceReps: reps,
    sourceRPE: rpe,
    confidence: confidence
  )
}

@Test func eligibilityGateMatchesSpec050() {
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: 8, family: .squat))
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: nil, family: .squat))
  #expect(
    E1RMEligibility.isEligible(
      completed: false, reps: 5, rpe: 8, family: .squat
    ) == false
  )
  #expect(
    E1RMEligibility.isEligible(
      failed: true, reps: 5, rpe: 8, family: .squat
    ) == false
  )
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: 6.5, family: .squat) == false)
  #expect(E1RMEligibility.isEligible(reps: 11, rpe: 9, family: .squat) == false)
  #expect(E1RMEligibility.isEligible(reps: 6, rpe: 9, family: .deadlift) == false)
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: 9, family: .deadlift))
  #expect(E1RMEligibility.isEligible(reps: 6, rpe: 9, family: .bench))
}

@Test func ineligibleSpikeDoesNotMoveTheSeries() {
  let series = E1RMSeries.build(
    points: [
      seriesPoint(daysAgo: 10, e1RM: 180),
      seriesPoint(daysAgo: 5, e1RM: 178),
      seriesPoint(daysAgo: 1, e1RM: 205, reps: 12),
    ],
    family: .squat
  )

  #expect(series.currentKg == 180)
  #expect(series.rawEligible.count == 2)
  #expect(series.best?.valueKg == 180)
  #expect(series.last?.valueKg == 178)
}

@Test func rollingMaxHoldsAValleyThenReleasesAfterFourWeeks() {
  let series = E1RMSeries.build(
    points: [
      seriesPoint(daysAgo: 40, e1RM: 185),
      seriesPoint(daysAgo: 20, e1RM: 175),
      seriesPoint(daysAgo: 1, e1RM: 178),
    ],
    family: .squat
  )

  #expect(series.smoothed[1].valueKg == 185)
  #expect(series.currentKg == 178)
  #expect(series.best?.valueKg == 185)
  #expect(series.last?.valueKg == 178)
}

@Test func eligiblePRMovesTheSeriesImmediately() {
  let series = E1RMSeries.build(
    points: [
      seriesPoint(daysAgo: 10, e1RM: 180),
      seriesPoint(daysAgo: 0, e1RM: 190, reps: 3, rpe: 9),
    ],
    family: .squat
  )

  #expect(series.currentKg == 190)
}

@Test func lowConfidenceSpikeIsOnlyKeptAsRawScatter() {
  let series = E1RMSeries.build(
    points: [
      seriesPoint(daysAgo: 10, e1RM: 180),
      seriesPoint(daysAgo: 5, e1RM: 178),
      seriesPoint(daysAgo: 1, e1RM: 320, reps: 3, rpe: 8.5, confidence: .low),
    ],
    family: .squat
  )

  #expect(series.currentKg == 180)
  #expect(series.best?.valueKg == 180)
  #expect(series.last?.valueKg == 178)
  #expect(series.rawEligible.count == 3)
  #expect(series.rawEligible.contains { $0.valueKg == 320 })
}

@Test func smoothedHistoryExcludesLowConfidenceSpike() {
  let history = E1RMSeries.smoothedHistory(
    points: [
      seriesPoint(daysAgo: 10, e1RM: 180),
      seriesPoint(daysAgo: 1, e1RM: 320, reps: 3, rpe: 8.5, confidence: .low),
    ],
    family: .squat
  )

  #expect(history.count == 1)
  #expect(history.first?.e1RMKg == 180)
}
