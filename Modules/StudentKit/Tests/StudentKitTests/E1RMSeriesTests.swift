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
  confidence: E1RMConfidence = .normal,
  origin: E1RMPointOrigin = .logged,
  sourceWeightKg: Double? = nil,
  setLogID: UUID = UUID()
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: seriesStudentID,
    exerciseId: seriesExerciseID,
    setLogId: setLogID,
    computedAt: seriesNow.addingTimeInterval(TimeInterval(-daysAgo) * 86_400),
    e1RMKg: e1RM,
    sourceWeightKg: sourceWeightKg ?? e1RM * 0.85,
    sourceReps: reps,
    sourceRPE: rpe,
    confidence: confidence,
    origin: origin
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

@Test func consecutiveSamplesKeepUniqueIdentityWhileOneWinnerCarries() {
  let winner = seriesPoint(daysAgo: 5, e1RM: 165, origin: .imported)
  let next = seriesPoint(daysAgo: 3, e1RM: 160)
  let latest = seriesPoint(daysAgo: 1, e1RM: 158)
  let series = E1RMSeries.build(points: [winner, next, latest], family: .squat)

  #expect(Set(series.smoothed.map(\.sampleID)).count == 3)
  #expect(series.smoothed.map(\.winnerPointID) == [winner.id, winner.id, winner.id])
}

@Test func mixedWindowUsesTheWholeImportedWinnerPoint() {
  let winnerSetLogID = UUID()
  let imported = seriesPoint(
    daysAgo: 5,
    e1RM: 165,
    reps: 3,
    rpe: 9,
    origin: .imported,
    sourceWeightKg: 150,
    setLogID: winnerSetLogID
  )
  let logged = seriesPoint(daysAgo: 1, e1RM: 160, sourceWeightKg: 140)
  let series = E1RMSeries.build(points: [imported, logged], family: .squat)
  let latest = series.smoothed.last

  #expect(latest?.sampleID == logged.id)
  #expect(latest?.winnerPointID == imported.id)
  #expect(latest?.winnerOrigin == .imported)
  #expect(latest?.winnerConfidence == .normal)
  #expect(latest?.valueKg == 165)

  let history = E1RMSeries.smoothedHistory(points: [imported, logged], family: .squat)
  let projected = history.last
  #expect(projected?.id == logged.id)
  #expect(projected?.computedAt == logged.computedAt)
  #expect(projected?.e1RMKg == imported.e1RMKg)
  #expect(projected?.origin == imported.origin)
  #expect(projected?.confidence == imported.confidence)
  #expect(projected?.sourceWeightKg == imported.sourceWeightKg)
  #expect(projected?.sourceReps == imported.sourceReps)
  #expect(projected?.sourceRPE == imported.sourceRPE)
  #expect(projected?.setLogId == winnerSetLogID)
}

@Test func lowConfidencePointStaysRawAndCannotBecomeBest() {
  let trusted = seriesPoint(daysAgo: 5, e1RM: 165, origin: .imported)
  let low = seriesPoint(
    daysAgo: 1,
    e1RM: 190,
    confidence: .low,
    origin: .imported
  )
  let series = E1RMSeries.build(points: [trusted, low], family: .squat)

  #expect(series.rawEligible.map(\.sampleID).contains(low.id))
  #expect(series.smoothed.map(\.sampleID).contains(low.id) == false)
  #expect(series.best?.winnerPointID == trusted.id)
}

@Test func smoothedHistoryUsesUniqueSampleIDsAndWinnerPayload() {
  let winnerSetLogID = UUID()
  let winner = seriesPoint(
    daysAgo: 5,
    e1RM: 165,
    reps: 2,
    rpe: 9.5,
    origin: .imported,
    sourceWeightKg: 155,
    setLogID: winnerSetLogID
  )
  let next = seriesPoint(daysAgo: 3, e1RM: 160)
  let latest = seriesPoint(daysAgo: 1, e1RM: 158)
  let history = E1RMSeries.smoothedHistory(
    points: [winner, next, latest],
    family: .squat
  )

  #expect(Set(history.map(\.id)).count == 3)
  #expect(history.map(\.id) == [winner.id, next.id, latest.id])
  #expect(history.allSatisfy { $0.e1RMKg == winner.e1RMKg })
  #expect(history.allSatisfy { $0.origin == winner.origin })
  #expect(history.allSatisfy { $0.confidence == winner.confidence })
  #expect(history.allSatisfy { $0.sourceWeightKg == winner.sourceWeightKg })
  #expect(history.allSatisfy { $0.sourceReps == winner.sourceReps })
  #expect(history.allSatisfy { $0.sourceRPE == winner.sourceRPE })
  #expect(history.allSatisfy { $0.setLogId == winnerSetLogID })
}

@Test func equalRollingMaximumKeepsTheEarlierPoint() {
  let earlier = seriesPoint(daysAgo: 5, e1RM: 165, origin: .imported)
  let later = seriesPoint(daysAgo: 1, e1RM: 165)
  let series = E1RMSeries.build(points: [earlier, later], family: .squat)

  #expect(series.smoothed.last?.winnerPointID == earlier.id)
  #expect(series.smoothed.last?.winnerOrigin == .imported)
}
