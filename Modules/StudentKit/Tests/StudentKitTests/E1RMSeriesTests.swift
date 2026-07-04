import CoreModels
import Foundation
import Testing

@testable import StudentKit

// Spec 050 §1/§2: the eligibility gate and the single aggregation.

private let student = UUID()
private let squat = UUID()

private func point(
  daysAgo: Int,
  e1RM: Double,
  reps: Int = 5,
  rpe: Double? = 8,
  base: Date = Date(timeIntervalSince1970: 1_782_000_000)
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: student,
    exerciseId: squat,
    setLogId: UUID(),
    computedAt: base.addingTimeInterval(TimeInterval(-daysAgo * 86_400)),
    e1RMKg: e1RM,
    sourceWeightKg: e1RM * 0.85,
    sourceReps: reps,
    sourceRPE: rpe
  )
}

@available(iOS 17.0, macOS 14.0, *)
@Test func eligibilityGateMatchesSpec050() {
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: 8, family: .squat))
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: nil, family: .squat))
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: 6.5, family: .squat) == false)
  #expect(E1RMEligibility.isEligible(reps: 11, rpe: 9, family: .squat) == false)
  #expect(E1RMEligibility.isEligible(reps: 6, rpe: 9, family: .deadlift) == false)
  #expect(E1RMEligibility.isEligible(reps: 5, rpe: 9, family: .deadlift))
  #expect(E1RMEligibility.isEligible(reps: 6, rpe: 9, family: .bench))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func ineligibleSpikeDoesNotMoveTheLine() {
  // Steady ~180, then a rep-12 blowup the formula would inflate to 205.
  let series = E1RMSeries.build(
    points: [
      point(daysAgo: 10, e1RM: 180),
      point(daysAgo: 5, e1RM: 178),
      point(daysAgo: 1, e1RM: 205, reps: 12),
    ],
    family: .squat
  )

  #expect(series.currentKg == 180)
  #expect(series.rawEligible.count == 2)
  #expect(series.best?.valueKg == 180)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func rollingMaxHoldsThroughAValleyAndReleasesAfterFourWeeks() {
  let series = E1RMSeries.build(
    points: [
      point(daysAgo: 40, e1RM: 185),
      point(daysAgo: 20, e1RM: 175),
      point(daysAgo: 1, e1RM: 178),
    ],
    family: .squat
  )

  // At day-20 the 185 from day-40 is still inside the 28-day window → holds.
  #expect(series.smoothed[1].valueKg == 185)
  // By day-1 the 185 has aged out; the window max is the recent 178.
  #expect(series.currentKg == 178)
  // Best stays the honest historical max.
  #expect(series.best?.valueKg == 185)
  #expect(series.last?.valueKg == 178)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func legitimatePRMovesTheLineImmediately() {
  let series = E1RMSeries.build(
    points: [
      point(daysAgo: 10, e1RM: 180),
      point(daysAgo: 0, e1RM: 190, reps: 3, rpe: 9),
    ],
    family: .squat
  )

  #expect(series.currentKg == 190)
}
