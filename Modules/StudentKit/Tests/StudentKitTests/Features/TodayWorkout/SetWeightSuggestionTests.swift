import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct SetWeightSuggestionTests {
  @Test func exerciseReferenceRetainsBestPointE1RM() {
    let point = E1RMHistoryPoint(
      id: UUID(),
      studentId: UUID(),
      exerciseId: UUID(),
      setLogId: UUID(),
      computedAt: Date(),
      e1RMKg: 187.5,
      sourceWeightKg: 160,
      sourceReps: 5,
      sourceRPE: 10
    )

    #expect(ExerciseReferenceSet(point: point).e1RMKg == 187.5)
  }

  @Test func matchingCompletedSetWinsOverE1RM() throws {
    let exerciseID = UUID()
    // Deliberately not a 2.5 multiple: the previous-set path must pass the
    // logged weight through unrounded (rounding is e1RM-path only).
    let previous = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 10),
      actualWeight: 93.8,
      completed: true
    )
    let target = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 1, reps: 5, rpe: 10)
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [previous, target],
        currentE1RMKg: 100
      ))

    #expect(suggestion.weightKg == 93.8)
    #expect(suggestion.basis == .previousSet)
  }

  @Test func uncompletedMismatchedRPEOrOtherExerciseSetsAreIgnored() throws {
    let exerciseID = UUID()
    let uncompleted = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 10),
      actualWeight: 93.8
    )
    let otherRPE = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 1, reps: 5, rpe: 9),
      actualWeight: 91.3,
      completed: true
    )
    let otherExercise = draft(
      exerciseID: UUID(),
      prescribed: prescription(setIndex: 2, reps: 5, rpe: 10),
      actualWeight: 88.1,
      completed: true
    )
    let target = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 3, reps: 5, rpe: 10)
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [uncompleted, otherRPE, otherExercise, target],
        currentE1RMKg: 100
      ))

    #expect(suggestion.basis == .e1RM(100))
    #expect(suggestion.weightKg == 85)
  }

  @Test func forwardComputedE1RMSurvivesFloorWithoutDroppingAStep() throws {
    // 50kg × 7 @ RPE 7 → e1RM = 50 / 0.70 (a float quotient); reversing must
    // suggest 50 again, not fall to 47.5 on a 49.999… floor edge.
    let e1RM = try #require(E1RMCalculator.calculate(weightKg: 50, reps: 7, rpe: 7))
    let target = draft(
      exerciseID: UUID(),
      prescribed: prescription(setIndex: 0, reps: 7, rpe: 7)
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [target],
        currentE1RMKg: e1RM
      ))

    #expect(suggestion.weightKg == 50)
  }

  @Test func persistedUntouchedSeedKeepsSuggestionUntilCompletedOrEdited() {
    let exerciseID = UUID()
    // Camera flow persisted the untouched 85kg seed (e1RM 100 × 5 @ 10 → 85).
    let rebuilt = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 10),
      actualWeight: 85
    )
    #expect(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: rebuilt.id, in: [rebuilt], currentE1RMKg: 100)?.basis == .e1RM(100))

    let edited = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 10),
      actualWeight: 87.5
    )
    #expect(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: edited.id, in: [edited], currentE1RMKg: 100) == nil)

    let completed = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 10),
      actualWeight: 85,
      completed: true
    )
    #expect(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: completed.id, in: [completed], currentE1RMKg: 100) == nil)
  }

  @Test func differentPrescriptionFallsBackToRoundedE1RMWeight() throws {
    let exerciseID = UUID()
    let previous = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 3, rpe: 10),
      actualWeight: 92.5,
      completed: true
    )
    let target = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 1, reps: 5, rpe: 10)
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [previous, target],
        currentE1RMKg: 100
      ))

    #expect(suggestion.weightKg == 85)
    #expect(suggestion.basis == .e1RM(100))
  }

  @Test func missingHistoryLeavesWeightUnseeded() {
    let target = draft(
      exerciseID: UUID(),
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 8)
    )

    let suggestion = TodayWorkoutViewModel.weightSuggestion(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: nil
    )

    #expect(suggestion == nil)
  }

  @Test func existingActualOrPrescribedWeightIsNeverOverridden() {
    let exerciseID = UUID()
    let actual = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 8),
      actualWeight: 80
    )
    let prescribed = draft(
      exerciseID: exerciseID,
      prescribed: PrescribedSet(
        id: UUID(), setIndex: 1, weightKg: 82.5, reps: 5, rpe: 8)
    )

    #expect(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: actual.id, in: [actual], currentE1RMKg: 100) == nil)
    #expect(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: prescribed.id, in: [prescribed], currentE1RMKg: 100) == nil)
  }

  @Test func variationSameDayCompletedSetWinsRegardlessOfPrescription() throws {
    let exerciseID = UUID()
    let previous = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 0, reps: 12, rpe: 7),
      actualWeight: 61.3,
      completed: true,
      isMainLift: false
    )
    let target = draft(
      exerciseID: exerciseID,
      prescribed: prescription(setIndex: 1, reps: 8, rpe: 8),
      isMainLift: false
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [previous, target],
        currentE1RMKg: 100,
        lastLoggedWeightKg: 55
      ))

    #expect(suggestion.weightKg == 61.3)
    #expect(suggestion.basis == .previousSet)
  }

  @Test func variationFallsBackToLastLoggedWeightAndNeverUsesE1RM() throws {
    let target = draft(
      exerciseID: UUID(),
      prescribed: prescription(setIndex: 0, reps: 12, rpe: 7),
      isMainLift: false
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [target],
        currentE1RMKg: 100,
        lastLoggedWeightKg: 62.5
      ))
    #expect(suggestion.weightKg == 62.5)
    #expect(suggestion.basis == .lastLogged)

    // e1RM alone must not produce a suggestion off the main-lift path.
    #expect(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [target],
        currentE1RMKg: 100,
        lastLoggedWeightKg: nil
      ) == nil)
  }

  @Test func mainLiftIgnoresLastLoggedWeight() throws {
    let target = draft(
      exerciseID: UUID(),
      prescribed: prescription(setIndex: 0, reps: 5, rpe: 10)
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [target],
        currentE1RMKg: 100,
        lastLoggedWeightKg: 62.5
      ))
    #expect(suggestion.basis == .e1RM(100))
    #expect(suggestion.weightKg == 85)
  }

  private func prescription(setIndex: Int, reps: Int, rpe: Decimal) -> PrescribedSet {
    PrescribedSet(id: UUID(), setIndex: setIndex, reps: reps, rpe: rpe)
  }

  private func draft(
    exerciseID: UUID,
    prescribed: PrescribedSet,
    actualWeight: Decimal? = nil,
    completed: Bool = false,
    isMainLift: Bool = true
  ) -> TodayWorkoutViewModel.SetRowDraft {
    TodayWorkoutViewModel.SetRowDraft(
      id: prescribed.id,
      planExerciseID: UUID(),
      exerciseID: exerciseID,
      exerciseName: "深蹲",
      isAccessory: false,
      isMainLift: isMainLift,
      prescribed: prescribed,
      actualWeight: actualWeight,
      completed: completed
    )
  }
}

@Suite struct LastWeightsTests {
  @Test func lastWeightsPicksLatestCompletedLogPerExercise() {
    let exerciseID = UUID()
    let legacyPlanExerciseID = UUID()
    let logs = [
      setLog(exerciseID: exerciseID, weightKg: 50, daysAgo: 10),
      setLog(exerciseID: exerciseID, weightKg: 57.5, daysAgo: 3),
      setLog(exerciseID: exerciseID, weightKg: 60, daysAgo: 1, completed: false),
      setLog(exerciseID: exerciseID, weightKg: 62.5, daysAgo: 1, failed: true),
      setLog(exerciseID: nil, planExerciseID: legacyPlanExerciseID, weightKg: 41.3, daysAgo: 2),
      setLog(exerciseID: nil, planExerciseID: UUID(), weightKg: 99, daysAgo: 1),
    ]
    let mappedExerciseID = UUID()

    let weights = TodayWorkoutViewModel.lastWeights(
      from: logs,
      planExerciseToExercise: [legacyPlanExerciseID: mappedExerciseID]
    )

    #expect(weights[exerciseID] == 57.5)
    #expect(weights[mappedExerciseID] == 41.3)
    #expect(weights.count == 2)
  }

  @Test func historyRangeExcludesTheViewedDayEntirely() {
    let dayDate = Date()
    let range = TodayWorkoutViewModel.lastWeightHistoryRange(before: dayDate)
    let dayStart = TodayWorkoutViewModel.dayRange(containing: dayDate).lowerBound

    #expect(range.upperBound == dayStart.addingTimeInterval(-1))
    #expect(!range.contains(dayStart))
    // Both bounds anchor to dayStart — a lower bound derived from the already
    // -1s upper bound would widen the window to 85 calendar days backend-side.
    #expect(
      range.lowerBound
        == dayStart.addingTimeInterval(
          -Double(TodayWorkoutViewModel.lastWeightLookbackDays) * 86_400))
  }

  private func setLog(
    exerciseID: UUID?,
    planExerciseID: UUID = UUID(),
    weightKg: Decimal,
    daysAgo: Int,
    completed: Bool = true,
    failed: Bool = false
  ) -> StudentSetLog {
    StudentSetLog(
      id: UUID(),
      studentID: UUID(),
      planExerciseID: planExerciseID,
      exerciseID: exerciseID,
      setIndex: 0,
      loggedAt: Date().addingTimeInterval(-Double(daysAgo) * 86_400),
      weightKg: weightKg,
      reps: 10,
      rpe: 8,
      completed: completed,
      failed: failed
    )
  }
}
