import CoreModels
import Foundation
import Testing

@testable import CoachKit

// MARK: - WeightEntryDraft pad/stepper/percent state machine

@available(iOS 17.0, macOS 14.0, *)
@Test func draftStartsEmptyForZeroAndFormattedOtherwise() {
  #expect(WeightEntryDraft(initialValue: 0).displayText == "0")
  #expect(WeightEntryDraft(initialValue: Decimal(142.5)).displayText == "142.5")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func padDigitsAppendWithSingleDecimalPlace() {
  var draft = WeightEntryDraft(initialValue: 0)
  draft.tapDigit(1)
  draft.tapDigit(4)
  draft.tapDigit(2)
  draft.tapDot()
  draft.tapDigit(5)
  #expect(draft.value == Decimal(142.5))

  // Second decimal digit and second dot are ignored.
  draft.tapDigit(7)
  draft.tapDot()
  #expect(draft.displayText == "142.5")

  draft.tapBackspace()
  draft.tapBackspace()
  #expect(draft.value == 142)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func steppersClampAtZeroAndStayOnHalfGrid() {
  var draft = WeightEntryDraft(initialValue: Decimal(100))
  draft.step(by: Decimal(25) / 10)
  #expect(draft.value == Decimal(102.5))
  draft.step(by: -5)
  #expect(draft.value == Decimal(97.5))

  var floor = WeightEntryDraft(initialValue: Decimal(2))
  floor.step(by: -5)
  #expect(floor.value == 0)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func percentOfBaseLandsOnPlateGrid() {
  var draft = WeightEntryDraft(initialValue: 0)
  // 80% × 180 = 144 → nearest 2.5 grid = 145.
  draft.apply(percent: 80, of: 180)
  #expect(draft.value == 145)
  // 75% × 142.5 = 106.875 → 107.5.
  draft.apply(percent: 75, of: Decimal(142.5))
  #expect(draft.value == Decimal(107.5))
  // Invalid base ignored.
  let before = draft.value
  draft.apply(percent: 80, of: 0)
  #expect(draft.value == before)
}

// MARK: - Weight panel bases (PlanningViewModel)

@available(iOS 17.0, macOS 14.0, *)
private func makeProfile() -> OnboardingProfile {
  OnboardingProfile(
    userId: PlanningFixtures.activeStudentID,
    squat1RMKg: 180,
    bench1RMKg: 120,
    deadlift1RMKg: 220,
    trainingDays: [.mon, .wed, .fri, .sat],
    gymTier: .homeWithRack,
    equipmentOverrides: [],
    createdAt: PlanningFixtures.now,
    updatedAt: PlanningFixtures.now
  )
}

@available(iOS 17.0, macOS 14.0, *)
private func activeStudent() -> CoachStudentSummary {
  PlanningFixtures.students()[1]
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weightEntryBasesOfferOneRMAndSameDayMainTopWeight() async throws {
  // 变式/回组按主项 top 组重量算 % (David 2026-06-12): the panel's bases
  // are the student's 1RM plus every OTHER same-day weight-mode main lift.
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .firstRegularPlan(activeStudent(), makeProfile())
  )
  await viewModel.bootstrap()
  viewModel.selectDuration(4)
  viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 1, deadlift: 1)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .bench)
  viewModel.toggleAssignment(dayOfWeek: 3, liftFamily: .deadlift)
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .squat)] =
    PlanningFixtures.squatID
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .bench)] =
    PlanningFixtures.benchID
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 3, liftFamily: .deadlift)] =
    PlanningFixtures.deadliftID
  viewModel.path = [.selectDuration, .assignFrequency, .selectMainLifts]
  try await viewModel.goNext()

  let squat = try #require(
    viewModel.mainLiftDraftExercise(for: DayLiftKey(dayOfWeek: 1, liftFamily: .squat)))
  let bench = try #require(
    viewModel.mainLiftDraftExercise(for: DayLiftKey(dayOfWeek: 1, liftFamily: .bench)))

  var spec = viewModel.defaultSetSpec(for: squat)
  spec.intensityMode = .weight
  spec.targetValue = 140
  try await viewModel.updateW1SetSpec(spec, for: squat.id)

  let benchBases = viewModel.weightEntryBases(for: bench)
  #expect(benchBases.contains { $0.label.hasPrefix("1RM·") && $0.amount == 120 })
  #expect(benchBases.contains { $0.label.hasPrefix("主项·") && $0.amount == 140 })

  // The squat's own bases never include itself; with no other weight-mode
  // main that day it offers only the 1RM.
  let squatBases = viewModel.weightEntryBases(for: squat)
  #expect(squatBases.count == 1)
  #expect(squatBases[0].amount == 180)

  // RPE-mode mains have no weight to compute from.
  spec.intensityMode = .rpe
  spec.targetValue = 8
  try await viewModel.updateW1SetSpec(spec, for: squat.id)
  #expect(!viewModel.weightEntryBases(for: bench).contains { $0.label.hasPrefix("主项·") })
}
