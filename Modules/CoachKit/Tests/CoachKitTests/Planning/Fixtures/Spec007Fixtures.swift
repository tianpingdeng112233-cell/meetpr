import CoreModels
import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
enum Spec007Fixtures {
  static let exerciseID = PlanningFixtures.uuid(200)

  static func setSpec(
    setCount: Int = 4,
    targetReps: Int = 5,
    intensityMode: IntensityMode = .weight,
    targetValue: Decimal = Decimal(100),
    restSeconds: Int? = nil,
    restSecondsPerSet: [Int]? = nil
  ) -> DraftSetSpec {
    DraftSetSpec(
      setCount: setCount,
      targetReps: targetReps,
      intensityMode: intensityMode,
      targetValue: targetValue,
      restSeconds: restSeconds,
      restSecondsPerSet: restSecondsPerSet
    )
  }

  static func rule(
    _ ruleType: ProgressionRuleType,
    increment: Decimal? = Decimal(5),
    sequence: [Decimal]? = nil,
    dimension: ProgressionRuleDimension? = nil,
    weeks: Set<Int> = [2],
    exerciseID: UUID = exerciseID,
    displayOrder: Int = 0
  ) -> DraftProgressionRule {
    DraftProgressionRule(
      ruleType: ruleType,
      incrementValue: increment,
      customSequence: sequence,
      customDimension: dimension,
      exerciseIDs: [exerciseID],
      appliedWeeks: weeks,
      displayOrder: displayOrder
    )
  }

  @MainActor
  static func configuredViewModelForStep5(
    weeks: Int = 4,
    addAccessory: Bool = true
  ) async throws -> PlanningViewModel {
    let viewModel = try PlanningFixtures.viewModel()
    await viewModel.bootstrap()
    viewModel.selectStudent(PlanningFixtures.students()[1])
    viewModel.selectDuration(weeks)
    viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 1, deadlift: 1)
    viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
    viewModel.toggleAssignment(dayOfWeek: 3, liftFamily: .bench)
    viewModel.toggleAssignment(dayOfWeek: 5, liftFamily: .deadlift)
    viewModel.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .squat)] =
      PlanningFixtures.squatID
    viewModel.selectedVariants[DayLiftKey(dayOfWeek: 3, liftFamily: .bench)] =
      PlanningFixtures.benchID
    viewModel.selectedVariants[DayLiftKey(dayOfWeek: 5, liftFamily: .deadlift)] =
      PlanningFixtures.deadliftID
    viewModel.path = [.selectDuration, .assignFrequency, .selectMainLifts]
    try await viewModel.goNext()

    if addAccessory {
      let dayID = try #require(viewModel.sortedDraftDays.first?.id)
      await viewModel.switchToDay(dayID)
      let accessory = try #require(viewModel.availableAccessories(for: dayID).first)
      try await viewModel.addAccessory(accessory, to: dayID)
    }

    try await viewModel.proceedToStep5()
    return viewModel
  }

  @MainActor
  static func fillAllW1SetSpecs(_ viewModel: PlanningViewModel) async throws {
    for exercise in viewModel.sortedDraftExercises {
      try await viewModel.updateW1SetSpec(
        setSpec(
          setCount: exercise.isMainLift ? 4 : 3,
          targetReps: exercise.isMainLift ? 5 : 10,
          targetValue: exercise.isMainLift ? Decimal(100) : Decimal(40)
        ),
        for: exercise.id
      )
    }
  }
}
