import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct IntensityWeightSuggestionTests {
  @Test func percentageUsesE1RMDirectlyWithoutProjectedRPE() throws {
    let target = intensityDraft(.percentage(72.5))

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [target],
        currentE1RMKg: 200
      )
    )

    #expect(suggestion.weightKg == 145)
    #expect(suggestion.basis == .e1RM(200))
  }

  @Test func percentageWithoutE1RMDoesNotInventWeight() {
    let target = intensityDraft(.percentage(72.5))

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: nil
    )

    #expect(outcome.suggestion == nil)
    #expect(outcome.unavailableReason == .noEligibleE1RMHistory)
  }

  @Test func percentageUsesE1RMForNonMainLift() throws {
    let target = intensityDraft(.percentage(72.5), isMainLift: false)

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [target],
        currentE1RMKg: 200,
        lastLoggedWeightKg: 100
      )
    )

    #expect(suggestion.weightKg == 145)
    #expect(suggestion.basis == .e1RM(200))
  }

  @Test(arguments: [
    PrescribedIntensity.rir(2),
    .rpeRange(8, 9),
    .weightRange(165, 175),
  ])
  func unsupportedIntensityFormsDoNotUseE1RM(intensity: PrescribedIntensity) {
    let target = intensityDraft(intensity)

    let suggestion = TodayWorkoutViewModel.weightSuggestion(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 200
    )

    #expect(suggestion == nil)
  }

  private func intensityDraft(
    _ intensity: PrescribedIntensity,
    isMainLift: Bool = true
  ) -> TodayWorkoutViewModel.SetRowDraft {
    let prescribed = PrescribedSet(
      id: UUID(), setIndex: 0, intensity: intensity, reps: 5)
    return TodayWorkoutViewModel.SetRowDraft(
      id: prescribed.id,
      planExerciseID: UUID(),
      exerciseID: UUID(),
      exerciseName: "深蹲",
      isAccessory: false,
      isMainLift: isMainLift,
      prescribed: prescribed
    )
  }
}
