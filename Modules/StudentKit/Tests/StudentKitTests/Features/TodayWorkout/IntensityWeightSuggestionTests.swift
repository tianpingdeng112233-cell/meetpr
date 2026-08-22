import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct IntensityWeightSuggestionTests {
  @Test(arguments: [
    PrescribedIntensity.rir(2),
    .rpeRange(8, 9),
    .weightRange(165, 175),
  ])
  func nonRPENewFormsDegradeQuietlyForMainLift(intensity: PrescribedIntensity) {
    let target = intensityDraft(intensity)

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 200
    )

    #expect(outcome.suggestion == nil)
    #expect(outcome.unavailableReason == nil)
  }

  // Accessory rows must not leak into the prior-set/last-logged fallback
  // either (round-1 review BLOCKER): same quiet degrade as main lifts.
  @Test(arguments: [
    PrescribedIntensity.rir(2),
    .rpeRange(8, 9),
    .weightRange(165, 175),
  ])
  func nonRPENewFormsDegradeQuietlyForAccessory(intensity: PrescribedIntensity) {
    let target = intensityDraft(intensity, isMainLift: false, isAccessory: true)

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 200,
      lastLoggedWeightKg: 100
    )

    #expect(outcome.suggestion == nil)
    #expect(outcome.unavailableReason == nil)
  }

  @Test func registeredOneRMPercentageResolvesAndRounds() throws {
    let target = intensityDraft(.percentage(60), registeredFamily: .squat)

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 210,
      registeredOneRMKg: 200
    )

    let suggestion = try #require(outcome.suggestion)
    #expect(suggestion.weightKg == 120)
    #expect(suggestion.basis == .percentage(.registeredOneRM(anchorKg: 200)))
  }

  @Test func e1RMPercentageUsesCurrentHeadlineValue() throws {
    let target = intensityDraft(
      .percentage(60),
      anchor: .e1RM,
      registeredFamily: .squat
    )

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 210,
      registeredOneRMKg: 200
    )

    let suggestion = try #require(outcome.suggestion)
    #expect(suggestion.weightKg == 125)
    #expect(suggestion.basis == .percentage(.e1RM(anchorKg: 210)))
  }

  @Test func e1RMPercentageFallsBackToRegisteredOneRM() throws {
    let target = intensityDraft(
      .percentage(60),
      anchor: .e1RM,
      registeredFamily: .squat
    )

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: nil,
      registeredOneRMKg: 200
    )

    let suggestion = try #require(outcome.suggestion)
    #expect(suggestion.weightKg == 120)
    #expect(suggestion.basis == .percentage(.fallbackToRegisteredOneRM(anchorKg: 200)))
  }

  @Test func accessoryPercentageIsUnresolvedAndNeverPrefills() {
    let target = intensityDraft(
      .percentage(60),
      isMainLift: false,
      isAccessory: true,
      registeredFamily: nil
    )

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 210,
      lastLoggedWeightKg: 100,
      registeredOneRMKg: 200
    )

    #expect(outcome.suggestion == nil)
    #expect(outcome.unavailableReason == .unsupportedPercentageExercise)
  }

  @Test func percentageRoundingMatchesSuggestionEnginePlateStep() throws {
    let target = intensityDraft(.percentage(60), registeredFamily: .squat)
    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: nil,
      registeredOneRMKg: 123
    )

    #expect(try #require(outcome.suggestion).weightKg == 72.5)
    #expect(
      try #require(outcome.suggestion).weightKg
        == SetWeightSuggestionRounding.roundedDownToPlateStep(123 * 0.6)
    )
  }

  @Test func completedBackoffKeepsActualWeightWhenTopSetChanges() {
    let exerciseID = UUID()
    let prior = intensityDraft(
      .rpe(8),
      registeredFamily: .squat,
      planExerciseSortOrder: 1,
      exerciseID: exerciseID,
      completed: true,
      actualWeight: 200,
      actualReps: 1
    )
    let completedBackoff = intensityDraft(
      .percentage(85),
      anchor: .topSet,
      registeredFamily: .squat,
      planExerciseSortOrder: 2,
      exerciseID: exerciseID,
      completed: true,
      actualWeight: 165,
      actualReps: 5
    )

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: completedBackoff.id,
      in: [prior, completedBackoff],
      currentE1RMKg: nil,
      registeredOneRMKg: 220
    )

    #expect(outcome.suggestion == nil)
    #expect(completedBackoff.actualWeight == 165)
  }

  // A new-form plain-RPE row keeps the existing RPE suggestion pipeline.
  @Test func newFormRPERowStillUsesRPEPipeline() throws {
    let target = intensityDraft(.rpe(8), loadMode: .rpe)

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 200
    )

    let suggestion = try #require(outcome.suggestion)
    #expect(suggestion.basis == .e1RM(200))
  }

  private func intensityDraft(
    _ intensity: PrescribedIntensity,
    loadMode: PlanLoadMode? = nil,
    isMainLift: Bool = true,
    isAccessory: Bool = false,
    anchor: PercentageAnchor = .registeredOneRM,
    registeredFamily: LiftFamily? = nil,
    planExerciseSortOrder: Int = 0,
    exerciseID: UUID = UUID(),
    planExerciseID: UUID = UUID(),
    completed: Bool = false,
    failed: Bool = false,
    actualWeight: Decimal? = nil,
    actualReps: Int? = nil
  ) -> TodayWorkoutViewModel.SetRowDraft {
    let resolvedLoadMode = loadMode ?? inferredLoadMode(for: intensity)
    let prescribed = PrescribedSet(
      id: UUID(), setIndex: 0, intensity: intensity,
      percentageAnchor: resolvedLoadMode == .percentage ? anchor : nil,
      loadMode: resolvedLoadMode, reps: 5)
    return TodayWorkoutViewModel.SetRowDraft(
      id: prescribed.id,
      planExerciseID: planExerciseID,
      exerciseID: exerciseID,
      exerciseName: "深蹲",
      isAccessory: isAccessory,
      isMainLift: isMainLift,
      liftFamily: registeredFamily,
      planExerciseSortOrder: planExerciseSortOrder,
      prescribed: prescribed,
      actualWeight: actualWeight,
      actualReps: actualReps,
      completed: completed,
      failed: failed
    )
  }

  private func inferredLoadMode(for intensity: PrescribedIntensity) -> PlanLoadMode {
    switch intensity {
    case .percentage: .percentage
    case .rpe: .rpe
    case .rir: .rir
    case .rpeRange: .rpeRange
    case .weightRange: .weightRange
    }
  }
}
