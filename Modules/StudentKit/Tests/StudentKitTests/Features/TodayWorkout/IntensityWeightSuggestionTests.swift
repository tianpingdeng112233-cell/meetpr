import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct IntensityWeightSuggestionTests {
  // ⚖️2026-08-12 pct anchors are tiered (1RM/e1RM/top set, default 1RM);
  // converting with e1RM against a 1RM-anchored percentage is fabricated data,
  // so every non-RPE new form degrades quietly until pct_anchor lands (卡 2).
  @Test(arguments: [
    PrescribedIntensity.percentage(72.5),
    .rir(2),
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
    PrescribedIntensity.percentage(72.5),
    .rir(2),
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
    isAccessory: Bool = false
  ) -> TodayWorkoutViewModel.SetRowDraft {
    let resolvedLoadMode = loadMode ?? inferredLoadMode(for: intensity)
    let prescribed = PrescribedSet(
      id: UUID(), setIndex: 0, intensity: intensity, loadMode: resolvedLoadMode, reps: 5)
    return TodayWorkoutViewModel.SetRowDraft(
      id: prescribed.id,
      planExerciseID: UUID(),
      exerciseID: UUID(),
      exerciseName: "深蹲",
      isAccessory: isAccessory,
      isMainLift: isMainLift,
      prescribed: prescribed
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
