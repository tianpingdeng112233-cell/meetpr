import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct HeroPrescriptionRowsTests {
  @Test func heterogeneousPrescriptionsKeepEachWeightAndDisplayNumber() {
    let exercise = makeExercise([
      makeRow(
        PrescribedSet(id: UUID(), setIndex: 2, weightKg: 140, loadMode: .fixedWeight, reps: 3)),
      makeRow(
        PrescribedSet(id: UUID(), setIndex: 3, weightKg: 125, loadMode: .fixedWeight, reps: 5)),
    ])
    #expect(exercise.prescriptionRows.map(\.number) == [3, 4])
    #expect(exercise.prescriptionRows.map(\.text) == ["140kg × 3", "125kg × 5"])
    #expect(exercise.prescriptionSummary == "2 组")
  }

  @Test func legacyPrescriptionsKeepLaterWeightsAndMissingWeight() {
    let exercise = makeExercise([
      makeRow(PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5)),
      makeRow(PrescribedSet(id: UUID(), setIndex: 1, weightKg: 92.5, reps: 6)),
      makeRow(PrescribedSet(id: UUID(), setIndex: 2, reps: 8)),
    ])
    #expect(exercise.prescriptionRows.map(\.text) == ["100kg × 5", "92.5kg × 6", "— × 8"])
    #expect(exercise.prescriptionSummary == nil)
  }

  @Test func prescriptionRowsExcludeExtraAndStudentAddedSets() {
    let planned = makeRow(PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5))
    let extra = makeRow(
      PrescribedSet(id: UUID(), setIndex: 1, weightKg: 110, reps: 3), extra: true)
    let added = makeRow(
      PrescribedSet(id: UUID(), setIndex: 2, weightKg: 120, reps: 2), added: true)
    let exercise = makeExercise([planned, extra, added])
    #expect(exercise.prescriptionRows.map(\.id) == [planned.id])
    #expect(exercise.prescriptionRows.map(\.number) == [1])
    #expect(exercise.prescriptionRows.map(\.text) == ["100kg × 5"])
  }

  @Test func percentagePrescriptionIncludesResolvedWeight() {
    let set = PrescribedSet(
      id: UUID(), setIndex: 0, intensity: .percentage(75), loadMode: .percentage, reps: 3)
    let outcome = SetWeightSuggestionOutcome(
      suggestion: .init(weightKg: 150, basis: .percentage(.registeredOneRM(anchorKg: 200))),
      unavailableReason: nil)
    let exercise = makeExercise([makeRow(set, outcome: outcome)])
    #expect(exercise.prescriptionRows.map(\.text) == ["≈ 150 kg · 75% · 1RM × 3"])
  }

  private func makeExercise(_ rows: [TodayWorkoutPresentation.Row])
    -> TodayWorkoutPresentation.Exercise
  {
    .init(
      id: UUID(), stableIndex: 0, name: "深蹲", reference: "", cardSubtitle: "", note: "", rows: rows)
  }

  private func makeRow(
    _ set: PrescribedSet, extra: Bool = false, added: Bool = false,
    outcome: SetWeightSuggestionOutcome? = nil
  ) -> TodayWorkoutPresentation.Row {
    var draft = TodayWorkoutSetRowDraft(
      id: set.id, planExerciseID: UUID(), exerciseID: UUID(), exerciseName: "深蹲",
      isAccessory: false, prescribed: set)
    draft.isExtra = extra
    draft.studentAddedDayID = added ? UUID() : nil
    return .init(
      id: set.id, stableIndex: 0,
      record: TodayWorkoutPresentation.record(
        from: draft, index: SetDisplayNumber.number(for: draft), videoState: .none),
      draft: draft, suggestionOutcome: outcome)
  }
}
