import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func suggestionBaselineExcludesUncalibratedLowRPEButDisplayKeepsIt() {
  let studentID = UUID()
  let exerciseID = UUID()
  let now = Date(timeIntervalSince1970: 1_782_000_000)
  let uncalibrated = E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: exerciseID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(-2 * 86_400),
    e1RMKg: 175,
    sourceWeightKg: 140,
    sourceReps: 5,
    sourceRPE: 6
  )
  let calibrated = E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: exerciseID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(-86_400),
    e1RMKg: 180,
    sourceWeightKg: 140,
    sourceReps: 5,
    sourceRPE: 6,
    sourceCoachRPE: 8
  )

  let display = E1RMSeries.trustedEligibleRaw(
    points: [uncalibrated, calibrated],
    family: .squat
  )
  let suggestion = E1RMSeries.trustedSuggestionEligibleRaw(
    points: [uncalibrated, calibrated],
    family: .squat
  )

  #expect(display.map(\.id) == [uncalibrated.id, calibrated.id])
  #expect(suggestion.map(\.id) == [calibrated.id])
}
