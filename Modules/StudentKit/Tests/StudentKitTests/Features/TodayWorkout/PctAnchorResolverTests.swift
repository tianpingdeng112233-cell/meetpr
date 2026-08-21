import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct PctAnchorResolverTests {
  private let exerciseID = UUID()

  @Test func topSetAfterBackoffIsNotAPrecedingCandidate() {
    let result = resolveTopSet(
      targetSortOrder: 1,
      sets: [logged(sortOrder: 2, weight: 200)]
    )

    #expect(result == unresolved(.topSetNotCompleted))
  }

  @Test func topSetUsesMaximumEligibleActualWeightOnly() {
    let otherExerciseID = UUID()
    let result = resolveTopSet(
      targetSortOrder: 10,
      sets: [
        logged(sortOrder: 1, weight: 180),
        logged(sortOrder: 2, weight: 190, failed: true),
        logged(sortOrder: 3, weight: 195, completed: false),
        logged(sortOrder: 4, weight: 0),
        logged(sortOrder: 5, weight: 205, reps: 0),
        logged(sortOrder: 6, weight: 200),
        logged(sortOrder: 7, weight: 220, exerciseID: otherExerciseID),
      ]
    )

    #expect(result.resolvedKg == 170)
    #expect(result.source == .topSet(anchorKg: 200))
  }

  @Test func unloggedTopSetIsNeverEstimatedInPlanState() {
    let result = resolveTopSet(
      targetSortOrder: 2,
      sets: [logged(sortOrder: 1, weight: 200, completed: false)]
    )

    #expect(result == unresolved(.topSetNotCompleted))
  }

  @Test func completingOrEditingPriorSetRecalculatesUnloggedBackoff() {
    let unavailable = resolveTopSet(
      targetSortOrder: 2,
      sets: [logged(sortOrder: 1, weight: nil, completed: false)]
    )
    let first = resolveTopSet(
      targetSortOrder: 2,
      sets: [logged(sortOrder: 1, weight: 200)]
    )
    let edited = resolveTopSet(
      targetSortOrder: 2,
      sets: [logged(sortOrder: 1, weight: 210)]
    )

    #expect(unavailable == unresolved(.topSetNotCompleted))
    #expect(first.resolvedKg == 170)
    #expect(edited.resolvedKg == 177.5)
  }

  @Test func disorderLoggingBackoffFirstHasNoTopSetAnchor() {
    let result = resolveTopSet(targetSortOrder: 2, sets: [])

    #expect(result == unresolved(.topSetNotCompleted))
  }

  private func resolveTopSet(
    targetSortOrder: Int,
    sets: [PctAnchorResolver.LoggedSet]
  ) -> PctAnchorResolution {
    PctAnchorResolver.resolve(
      PctAnchorResolver.Input(
        percentage: 85,
        anchor: .topSet,
        exerciseFamily: .squat,
        registeredOneRMKg: 220,
        currentE1RMKg: 225,
        exerciseID: exerciseID,
        planExerciseSortOrder: targetSortOrder,
        sameDaySets: sets
      )
    )
  }

  private func logged(
    sortOrder: Int,
    weight: Decimal?,
    reps: Int = 1,
    completed: Bool = true,
    failed: Bool = false,
    exerciseID: UUID? = nil
  ) -> PctAnchorResolver.LoggedSet {
    PctAnchorResolver.LoggedSet(
      exerciseID: exerciseID ?? self.exerciseID,
      planExerciseSortOrder: sortOrder,
      actualWeightKg: weight,
      actualReps: reps,
      completed: completed,
      failed: failed
    )
  }

  private func unresolved(_ reason: PctAnchorUnresolvedReason) -> PctAnchorResolution {
    PctAnchorResolution(resolvedKg: nil, source: .unresolved(reason))
  }
}
