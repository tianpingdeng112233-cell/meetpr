import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct GrowthE1RMDetailTests {
  @Test func detailUsesSelectedSnapshotAndExactSourceSet() throws {
    let plan = StudentDemoSeed.makePlanView()
    let exercise = try #require(plan.days.first?.exercises.first)
    let point = makePoint(exerciseID: exercise.exercise.id)
    let log = StudentSetLog(
      id: point.setLogId, studentID: point.studentId, planExerciseID: exercise.id,
      exerciseID: exercise.exercise.id, setIndex: 2, loggedAt: point.computedAt,
      weightKg: 160, reps: 4, rpe: 9, completed: true
    )
    let detail = GrowthE1RMDetail(point: point, logs: [log], days: plan.days)

    #expect(detail.id == point.id)
    #expect(detail.date == point.computedAt)
    #expect(detail.setNumber == 3)
    #expect(detail.exerciseName == StudentExerciseName.display(exercise.exercise))
    #expect(detail.point.sourceWeightKg == 152)
    #expect(detail.point.sourceReps == 5)
    #expect(detail.calculation == .rts(intensity: 0.78))
  }

  @Test(arguments: [nil, 5.5] as [Double?])
  func fallbackExplainsStoredEstimateWithoutRPELookup(rpe: Double?) {
    let point = makePoint(weight: 150, value: 175, rpe: rpe)
    let detail = GrowthE1RMDetail(point: point, logs: [], days: [])
    #expect(detail.calculation == .epley)
    #expect(detail.setNumber == nil)
    #expect(detail.exerciseName == nil)
  }

  @Test func incompatibleStoredValueDoesNotInventAnEquation() {
    let point = makePoint(value: 205)
    let detail = GrowthE1RMDetail(point: point, logs: [], days: [])
    #expect(detail.point.e1RMKg == 205)
    #expect(detail.calculation == .unavailable)
  }

  @Test func persistedCoachCalibrationSurvivesMissingOriginalLog() throws {
    let point = makePoint(rpe: 7.5, coachRPE: 8)
    let stored = try JSONEncoder().encode(point)
    let restored = try JSONDecoder().decode(E1RMHistoryPoint.self, from: stored)
    let detail = GrowthE1RMDetail(point: restored, logs: [], days: [])
    #expect(detail.point.sourceRPE == 7.5)
    #expect(detail.point.sourceCoachRPE == 8)
    #expect(detail.calculation == .rts(intensity: 0.78))
    #expect(detail.setNumber == nil)
  }

  @Test func unrelatedLogDoesNotSupplyAGroupNumber() {
    let point = makePoint()
    let unrelated = StudentSetLog(
      id: UUID(), studentID: point.studentId, planExerciseID: UUID(),
      exerciseID: point.exerciseId, setIndex: 9, loggedAt: point.computedAt,
      weightKg: 152, reps: 5, rpe: 8, completed: true
    )
    #expect(GrowthE1RMDetail(point: point, logs: [unrelated], days: []).setNumber == nil)
  }

  private func makePoint(
    exerciseID: UUID = UUID(), weight: Double = 152, value: Double = 194.9,
    rpe: Double? = 8, coachRPE: Double? = nil
  ) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: UUID(), studentId: StudentDemoSeed.studentID, exerciseId: exerciseID,
      setLogId: UUID(), computedAt: Date(timeIntervalSince1970: 1_768_262_400),
      e1RMKg: value, sourceWeightKg: weight, sourceReps: 5, sourceRPE: rpe,
      sourceCoachRPE: coachRPE
    )
  }
}
