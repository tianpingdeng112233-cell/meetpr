import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test(arguments: [
  (PrescribedSet(id: UUID(), setIndex: 0, intensity: .percentage(72.5), reps: 5), "72.5% × 5"),
  (PrescribedSet(id: UUID(), setIndex: 0, intensity: .rpeRange(8, 9), reps: 5), "RPE 8–9 × 5"),
  (
    PrescribedSet(id: UUID(), setIndex: 0, intensity: .weightRange(165, 175), reps: 5),
    "165–175kg × 5"
  ),
  (
    PrescribedSet(id: UUID(), setIndex: 0, weightKg: 170, intensity: .rpe(9), reps: 5),
    "170kg × 5 @RPE9"
  ),
  (PrescribedSet(id: UUID(), setIndex: 0, weightKg: 150, reps: 5), "150kg × 5"),
  (PrescribedSet(id: UUID(), setIndex: 0, intensity: .rir(2), reps: 5), "RIR 2 × 5"),
])
func prescribedIntensityFormattingIsFaithful(set: PrescribedSet, expected: String) {
  let rendered = StudentFormatting.prescribed(set)

  #expect(rendered == expected)
  #expect(!rendered.contains("-kg"))
}

@MainActor
@Test func heroUsesPercentageAsPrimaryTextWithoutFabricatedRPE() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, intensity: .percentage(72.5), reps: 5)
  let day = intensityDay(prescribed: prescribed)
  let presentation = TodayWorkoutPresentation(
    day: day,
    drafts: TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []),
    references: [:],
    started: true
  )
  let row = try #require(presentation.currentRow)

  #expect(row.heroPrimaryText == "72.5%")
  #expect(!row.heroShowsWeightUnit)
  #expect(row.heroSecondaryIntensityText == nil)
  #expect(row.draft.prescribed.rpe == nil)
  #expect(presentation.exercises.first?.prescriptionSummary == "72.5% × 5 · 1 组")
}

@MainActor
@Test func heroShowsIndependentRPEAlongsideWeight() throws {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: 170, intensity: .rpe(9), reps: 5)
  let day = intensityDay(prescribed: prescribed)
  let presentation = TodayWorkoutPresentation(
    day: day,
    drafts: TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []),
    references: [:],
    started: true
  )
  let row = try #require(presentation.currentRow)

  #expect(row.heroPrimaryText == "170")
  #expect(row.heroShowsWeightUnit)
  #expect(row.heroSecondaryIntensityText == "RPE 9")
}

private func intensityDay(prescribed: PrescribedSet) -> StudentPlanDay {
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
        id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: [prescribed])
    ]
  )
}
