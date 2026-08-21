import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test(arguments: [
  (
    PrescribedSet(
      id: UUID(), setIndex: 0, intensity: .percentage(72.5), loadMode: .percentage, reps: 5),
    "72.5% × 5"
  ),
  (
    PrescribedSet(
      id: UUID(), setIndex: 0, intensity: .rpeRange(8, 9), loadMode: .rpeRange, reps: 5),
    "RPE 8–9 × 5"
  ),
  (
    PrescribedSet(
      id: UUID(), setIndex: 0, intensity: .weightRange(165, 175), loadMode: .weightRange, reps: 5),
    "165–175kg × 5"
  ),
  (
    PrescribedSet(
      id: UUID(), setIndex: 0, weightKg: 170, intensity: .rpe(9), loadMode: .rpe, reps: 5),
    "170kg × 5 @RPE9"
  ),
  // Sparse single-value row: weight present, intensity value left empty.
  (
    PrescribedSet(id: UUID(), setIndex: 0, weightKg: 150, loadMode: .rpe, reps: 5),
    "150kg × 5"
  ),
  (
    PrescribedSet(
      id: UUID(), setIndex: 0, weightKg: 150, loadMode: .fixedWeight, reps: 5),
    "150kg × 5"
  ),
  (
    PrescribedSet(id: UUID(), setIndex: 0, intensity: .rir(2), loadMode: .rir, reps: 5),
    "RIR 2 × 5"
  ),
])
func prescribedIntensityFormattingIsFaithful(set: PrescribedSet, expected: String) {
  let rendered = StudentFormatting.prescribed(set)

  #expect(rendered == expected)
  #expect(!rendered.contains("-kg"))
}

// Legacy rows (load_mode == null) must keep the pre-072 strings byte-for-byte
// (spec 072 §1.4), including the dash placeholder and ASCII "x".
@Test(arguments: [
  (PrescribedSet(id: UUID(), setIndex: 0, weightKg: 140, reps: 5), "140kg x 5"),
  (PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8), "-kg x 5"),
  (PrescribedSet(id: UUID(), setIndex: 0, weightKg: 142.5, reps: 3, repsMax: 5), "142.5kg x 3-5"),
])
func legacyPrescriptionFormattingIsUnchanged(set: PrescribedSet, expected: String) {
  #expect(set.isLegacyPrescription)
  #expect(StudentFormatting.prescribed(set) == expected)
}

@MainActor
@Test func heroUsesPercentageAsPrimaryTextWithoutFabricatedRPE() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, intensity: .percentage(72.5), loadMode: .percentage, reps: 5)
  let presentation = intensityPresentation(prescribed: prescribed)
  let row = try #require(presentation.currentRow)

  #expect(row.heroPrimaryText == "72.5%")
  #expect(!row.heroShowsWeightUnit)
  #expect(row.heroSecondaryIntensityText == nil)
  #expect(row.draft.prescribed.rpe == nil)
  #expect(presentation.exercises.first?.prescriptionSummary == "72.5% × 5 · 1 组")
}

@MainActor
@Test func resolvedPercentageShowsApproximateWeightAndOriginalAnchor() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, intensity: .percentage(60),
    percentageAnchor: .registeredOneRM, loadMode: .percentage, reps: 5)
  let outcome = SetWeightSuggestionOutcome(
    suggestion: SetWeightSuggestion(
      weightKg: 120,
      basis: .percentage(.registeredOneRM(anchorKg: 200))
    ),
    unavailableReason: nil
  )
  let presentation = intensityPresentation(
    prescribed: [prescribed],
    suggestionOutcomes: [prescribed.id: outcome]
  )
  let row = try #require(presentation.currentRow)

  #expect(row.heroPrimaryText == "≈ 120")
  #expect(row.heroShowsWeightUnit)
  #expect(row.heroSecondaryIntensityText == "60% × 1RM")
  #expect(
    presentation.exercises.first?.prescriptionSummary
      == "≈ 120 kg · 60% × 1RM × 5 · 1 组"
  )
}

@MainActor
@Test func unresolvedTopSetShowsSemanticInstructionWithoutPrefill() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, intensity: .percentage(85),
    percentageAnchor: .topSet, loadMode: .percentage, reps: 5)
  let outcome = SetWeightSuggestionOutcome(
    suggestion: nil,
    unavailableReason: .topSetNotCompleted
  )
  let presentation = intensityPresentation(
    prescribed: [prescribed],
    suggestionOutcomes: [prescribed.id: outcome]
  )
  let row = try #require(presentation.currentRow)

  #expect(row.heroPrimaryText == "85% × 当日顶组 · 先完成顶组")
  #expect(!row.heroShowsWeightUnit)
  #expect(row.heroSecondaryIntensityText == nil)
}

@MainActor
@Test func unsupportedPercentageExerciseOnlyShowsOriginalPercentage() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, intensity: .percentage(60),
    percentageAnchor: .registeredOneRM, loadMode: .percentage, reps: 5)
  let outcome = SetWeightSuggestionOutcome(
    suggestion: nil,
    unavailableReason: .unsupportedPercentageExercise
  )
  let presentation = intensityPresentation(
    prescribed: [prescribed],
    suggestionOutcomes: [prescribed.id: outcome]
  )
  let row = try #require(presentation.currentRow)

  #expect(row.heroPrimaryText == "60%")
  #expect(!row.heroShowsWeightUnit)
}

@MainActor
@Test func heroShowsIndependentRPEAlongsideWeight() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: 170, intensity: .rpe(9), loadMode: .rpe, reps: 5)
  let presentation = intensityPresentation(prescribed: prescribed)
  let row = try #require(presentation.currentRow)

  #expect(row.heroPrimaryText == "170")
  #expect(row.heroShowsWeightUnit)
  #expect(row.heroSecondaryIntensityText == "RPE 9")
}

// A sparse new-form row (weight only) must not fall back into the legacy hero
// and resurrect the fabricated 目标 RPE 0/10 block.
@MainActor
@Test func sparseNewFormRowUsesNewHeroWithoutIntensityBlock() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: 150, loadMode: .rpe, reps: 5)
  let presentation = intensityPresentation(prescribed: prescribed)
  let row = try #require(presentation.currentRow)

  #expect(!row.usesLegacyHero)
  #expect(row.heroPrimaryText == "150")
  #expect(row.heroSecondaryIntensityText == nil)
}

// Legacy rows keep the pre-072 hero and the record-based exercise summary.
@MainActor
@Test func legacyRowKeepsLegacyHeroAndRecordSummary() throws {
  let prescribed = PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8)
  let presentation = intensityPresentation(prescribed: prescribed)
  let row = try #require(presentation.currentRow)

  #expect(row.usesLegacyHero)
  #expect(row.heroPrimaryText == "—")
  #expect(row.heroSecondaryIntensityText == nil)
  #expect(presentation.exercises.first?.prescriptionSummary == nil)
}

@MainActor
private func intensityPresentation(prescribed: PrescribedSet) -> TodayWorkoutPresentation {
  intensityPresentation(prescribed: [prescribed])
}

@MainActor
private func intensityPresentation(prescribed: [PrescribedSet]) -> TodayWorkoutPresentation {
  intensityPresentation(prescribed: prescribed, suggestionOutcomes: [:])
}

@MainActor
private func intensityPresentation(
  prescribed: [PrescribedSet],
  suggestionOutcomes: [UUID: SetWeightSuggestionOutcome]
) -> TodayWorkoutPresentation {
  let day = intensityDay(prescribed: prescribed)
  return TodayWorkoutPresentation(
    day: day,
    drafts: TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []),
    references: [:],
    suggestionOutcomes: suggestionOutcomes,
    started: true
  )
}

private func intensityDay(prescribed: [PrescribedSet]) -> StudentPlanDay {
  let exercise = Exercise(
    id: UUID(),
    name: "深蹲",
    exerciseType: .mainLift,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    createdAt: Date()
  )
  return StudentPlanDay(
    id: UUID(),
    date: Date(),
    exercises: [
      StudentPlanExercise(
        id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: prescribed)
    ]
  )
}

// Heterogeneous sets (spec §2) must not be passed off as uniform: the summary
// names a prescription only when every set renders identically.
@MainActor
@Test func heterogeneousSetsSummarizeAsCountOnly() throws {
  let first = PrescribedSet(
    id: UUID(), setIndex: 0, intensity: .percentage(72.5), loadMode: .percentage, reps: 5)
  let second = PrescribedSet(
    id: UUID(), setIndex: 1, weightKg: 170, intensity: .rpe(9), loadMode: .rpe, reps: 5)
  let presentation = intensityPresentation(prescribed: [first, second])

  #expect(presentation.exercises.first?.prescriptionSummary == "2 组")
}

// A legacy first set with a new-form set behind it must not hide the exercise
// behind the record-based fallback either.
@MainActor
@Test func mixedLegacyAndNewFormSetsSummarizeAsCountOnly() throws {
  let legacy = PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8)
  let newForm = PrescribedSet(
    id: UUID(), setIndex: 1, weightKg: 170, intensity: .rpe(9), loadMode: .rpe, reps: 5)
  let presentation = intensityPresentation(prescribed: [legacy, newForm])

  #expect(presentation.exercises.first?.prescriptionSummary == "2 组")
}

@MainActor
@Test func uniformSetsKeepNamedSummary() throws {
  let set = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: 150, loadMode: .fixedWeight, reps: 5)
  let second = PrescribedSet(
    id: UUID(), setIndex: 1, weightKg: 150, loadMode: .fixedWeight, reps: 5)
  let presentation = intensityPresentation(prescribed: [set, second])

  #expect(presentation.exercises.first?.prescriptionSummary == "150kg × 5 · 2 组")
}
