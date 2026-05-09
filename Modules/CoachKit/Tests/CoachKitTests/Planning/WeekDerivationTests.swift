import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationReturnsW1Baseline() {
  let baseline = Spec007Fixtures.setSpec()

  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 1,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: baseline,
    rules: [Spec007Fixtures.rule(.weightInc)]
  )

  #expect(derived == baseline)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationAppliesWeightIncrease() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetValue: 100),
    rules: [Spec007Fixtures.rule(.weightInc, increment: 5)]
  )

  #expect(derived.intensityMode == .weight)
  #expect(derived.targetValue == 105)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationAppliesWeightDecrease() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetValue: 100),
    rules: [Spec007Fixtures.rule(.weightDec, increment: 10)]
  )

  #expect(derived.targetValue == 90)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationAppliesRPEIncrease() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(intensityMode: .rpe, targetValue: 8),
    rules: [Spec007Fixtures.rule(.rpeInc, increment: 0.5)]
  )

  #expect(derived.intensityMode == .rpe)
  #expect(derived.targetValue == 8.5)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationAppliesRPEDecreaseAndClamps() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(intensityMode: .rpe, targetValue: 1.25),
    rules: [Spec007Fixtures.rule(.rpeDec, increment: 2)]
  )

  #expect(derived.targetValue == 1)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationAppliesSetsIncreaseAndDecreaseClamp() {
  let increased = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(setCount: 3),
    rules: [Spec007Fixtures.rule(.setsInc, increment: 1)]
  )
  let decreased = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(setCount: 1),
    rules: [Spec007Fixtures.rule(.setsDec, increment: 5)]
  )

  #expect(increased.setCount == 4)
  #expect(decreased.setCount == 1)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationAppliesRepsIncreaseAndDecreaseClamp() {
  let increased = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetReps: 5),
    rules: [Spec007Fixtures.rule(.repsInc, increment: 2)]
  )
  let decreased = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetReps: 1),
    rules: [Spec007Fixtures.rule(.repsDec, increment: 2)]
  )

  #expect(increased.targetReps == 7)
  #expect(decreased.targetReps == 1)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationUsesCustomSequenceBySortedAppliedWeek() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 3,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetValue: 100),
    rules: [
      Spec007Fixtures.rule(
        .custom,
        increment: nil,
        sequence: [110, 120, 130],
        dimension: .weight,
        weeks: [4, 2, 3]
      )
    ]
  )

  #expect(derived.targetValue == 120)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationDispatchesCustomRuleToEachDimension() {
  let weight = deriveCustom(dimension: .weight, value: 125)
  let rpe = deriveCustom(dimension: .rpe, value: 8.5)
  let sets = deriveCustom(dimension: .sets, value: 6)
  let reps = deriveCustom(dimension: .reps, value: 3)

  #expect(weight.targetValue == 125)
  #expect(weight.intensityMode == .weight)
  #expect(rpe.targetValue == 8.5)
  #expect(rpe.intensityMode == .rpe)
  #expect(sets.setCount == 6)
  #expect(reps.targetReps == 3)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationCombinesDifferentDimensions() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(setCount: 4, targetReps: 5, targetValue: 100),
    rules: [
      Spec007Fixtures.rule(.weightInc, increment: 5, displayOrder: 0),
      Spec007Fixtures.rule(.repsDec, increment: 1, displayOrder: 1),
    ]
  )

  #expect(derived.targetValue == 105)
  #expect(derived.targetReps == 4)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationUsesHigherDisplayOrderForSameDimension() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetValue: 100),
    rules: [
      Spec007Fixtures.rule(.weightInc, increment: 5, displayOrder: 0),
      Spec007Fixtures.rule(.weightInc, increment: 12.5, displayOrder: 1),
    ]
  )

  #expect(derived.targetValue == 112.5)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationDefaultsSkippedWeeksToPreviousWeek() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 4,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetValue: 100),
    rules: [Spec007Fixtures.rule(.weightInc, increment: 5, weeks: [2, 4])]
  )

  #expect(derived.targetValue == 110)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weekDerivationIgnoresRulesForOtherExercises() {
  let derived = WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(targetValue: 100),
    rules: [
      Spec007Fixtures.rule(
        .weightInc,
        exerciseID: PlanningFixtures.uuid(202)
      )
    ]
  )

  #expect(derived.targetValue == 100)
}

@available(iOS 17.0, macOS 14.0, *)
private func deriveCustom(
  dimension: ProgressionRuleDimension,
  value: Decimal
) -> DraftSetSpec {
  WeekDerivation.deriveSetSpec(
    forWeek: 2,
    exerciseID: Spec007Fixtures.exerciseID,
    w1: Spec007Fixtures.setSpec(),
    rules: [
      Spec007Fixtures.rule(
        .custom,
        increment: nil,
        sequence: [value],
        dimension: dimension
      )
    ]
  )
}
