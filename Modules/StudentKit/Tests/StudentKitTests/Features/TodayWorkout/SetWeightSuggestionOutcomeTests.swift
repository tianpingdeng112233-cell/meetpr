import CoreModels
import Foundation
import SwiftUI
import Testing

@testable import StudentKit

@Suite struct SetWeightSuggestionOutcomeTests {
  @Test func failedMatchingMainLiftSetFallsBackToE1RM() throws {
    let exerciseID = UUID()
    let failed = suggestionDraft(
      exerciseID: exerciseID,
      prescribed: suggestionPrescription(setIndex: 0, reps: 5, rpe: 10),
      actualWeight: 95,
      completed: true,
      failed: true
    )
    let target = suggestionDraft(
      exerciseID: exerciseID,
      prescribed: suggestionPrescription(setIndex: 1, reps: 5, rpe: 10)
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [failed, target],
        currentE1RMKg: 100
      )
    )

    #expect(suggestion.basis == .e1RM(100))
    #expect(suggestion.weightKg == 85)
  }

  @Test func failedVariationSetFallsBackToEarlierSessionWeight() throws {
    let exerciseID = UUID()
    let failed = suggestionDraft(
      exerciseID: exerciseID,
      prescribed: suggestionPrescription(setIndex: 0, reps: 10, rpe: 8),
      actualWeight: 70,
      completed: true,
      failed: true,
      isMainLift: false
    )
    let target = suggestionDraft(
      exerciseID: exerciseID,
      prescribed: suggestionPrescription(setIndex: 1, reps: 10, rpe: 8),
      isMainLift: false
    )

    let suggestion = try #require(
      TodayWorkoutViewModel.weightSuggestion(
        forSetID: target.id,
        in: [failed, target],
        currentE1RMKg: nil,
        lastLoggedWeightKg: 62.5
      )
    )

    #expect(suggestion.basis == .lastLogged)
    #expect(suggestion.weightKg == 62.5)
  }

  @Test(arguments: [
    (
      PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8),
      SetWeightSuggestionUnavailableReason.noEligibleE1RMHistory
    ),
    (
      PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: nil),
      SetWeightSuggestionUnavailableReason.missingPrescribedRPE
    ),
    (
      PrescribedSet(id: UUID(), setIndex: 0, reps: nil, rpe: 8),
      SetWeightSuggestionUnavailableReason.missingPrescribedReps
    ),
    (
      PrescribedSet(id: UUID(), setIndex: 0, reps: 13, rpe: 8),
      SetWeightSuggestionUnavailableReason.prescribedRepsOutsideSupportedRange
    ),
    (
      PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 4.5),
      SetWeightSuggestionUnavailableReason.prescribedRPEBelowSupportedRange
    ),
    (
      PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 10.5),
      SetWeightSuggestionUnavailableReason.prescribedRPEAboveSupportedRange
    ),
  ])
  func mainLiftUnavailableReasonMatchesPrescription(
    prescribed: PrescribedSet,
    expectedReason: SetWeightSuggestionUnavailableReason
  ) {
    let target = suggestionDraft(exerciseID: UUID(), prescribed: prescribed)

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: nil
    )

    #expect(outcome.suggestion == nil)
    #expect(outcome.unavailableReason == expectedReason)
  }

  @Test func variationWithoutHistoryReturnsExerciseHistoryReason() {
    let target = suggestionDraft(
      exerciseID: UUID(),
      prescribed: PrescribedSet(id: UUID(), setIndex: 0),
      isMainLift: false
    )

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: nil
    )

    #expect(outcome.suggestion == nil)
    #expect(outcome.unavailableReason == .noExerciseHistory)
  }

  @Test func availableSuggestionHasNoUnavailableReason() {
    let target = suggestionDraft(
      exerciseID: UUID(),
      prescribed: suggestionPrescription(setIndex: 0, reps: 5, rpe: 10)
    )

    let outcome = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id,
      in: [target],
      currentE1RMKg: 100
    )

    #expect(outcome.suggestion?.weightKg == 85)
    #expect(outcome.unavailableReason == nil)
  }

  @MainActor
  @Test func sheetKeepsUnavailableOutcomeAndDefaultWeightFromItsOpeningSnapshot() async throws {
    let fixture = try await makeSuggestionSheetFixture(seedHistory: false)
    let sheet = SetEntrySheet(
      rowIndex: 0,
      draft: fixture.draft,
      setNumber: 1,
      viewModel: fixture.viewModel
    )

    #expect(sheet.suggestionOutcomeSnapshot.unavailableReason == .noEligibleE1RMHistory)
    #expect(sheet.weightValue == 20)
    let snapshotStorage = Mirror(reflecting: sheet).children.first {
      $0.label == "_suggestionOutcomeSnapshot"
    }
    #expect(snapshotStorage?.value is State<SetWeightSuggestionOutcome>)

    _ = try await fixture.e1rm.upsertPoint(fixture.historyPoint)
    await fixture.viewModel.load(date: fixture.date, studentID: fixture.studentID)

    #expect(
      fixture.viewModel.weightSuggestionOutcome(forSetID: fixture.draft.id).suggestion != nil
    )
    #expect(sheet.suggestionOutcomeSnapshot.unavailableReason == .noEligibleE1RMHistory)
    #expect(sheet.weightValue == 20)
  }

  @MainActor
  @Test func sheetKeepsSuggestedWeightWithoutAddingALiveUnavailableHint() async throws {
    let fixture = try await makeSuggestionSheetFixture(seedHistory: true)
    let sheet = SetEntrySheet(
      rowIndex: 0,
      draft: fixture.draft,
      setNumber: 1,
      viewModel: fixture.viewModel
    )
    let suggestedWeight = try #require(sheet.suggestionOutcomeSnapshot.suggestion?.weightKg)

    try await fixture.e1rm.replaceHistory(
      studentId: fixture.studentID,
      with: [],
      weightBaselines: [],
      prEvents: []
    )
    await fixture.viewModel.load(date: fixture.date, studentID: fixture.studentID)

    #expect(
      fixture.viewModel.weightSuggestionOutcome(forSetID: fixture.draft.id).unavailableReason
        == .noEligibleE1RMHistory
    )
    #expect(sheet.suggestionOutcomeSnapshot.unavailableReason == nil)
    #expect(sheet.weightValue == suggestedWeight)
  }

  @MainActor
  @Test func sheetPrefillsFixedWeightAndLeavesPercentageEmpty() async throws {
    // pct anchors are tiered (⚖️2026-08-12, default 1RM): no conversion until
    // pct_anchor lands, so the sheet must stay empty rather than invent 90kg.
    let pctFixture = try await makeSuggestionSheetFixture(
      seedHistory: true,
      prescribed: PrescribedSet(
        id: UUID(), setIndex: 0, intensity: .percentage(75), loadMode: .percentage, reps: 5)
    )
    let pctSheet = SetEntrySheet(
      rowIndex: 0,
      draft: pctFixture.draft,
      setNumber: 1,
      viewModel: pctFixture.viewModel
    )
    let fixedFixture = try await makeSuggestionSheetFixture(
      seedHistory: false,
      prescribed: PrescribedSet(
        id: UUID(), setIndex: 0, weightKg: 150, loadMode: .fixedWeight, reps: 5)
    )
    let fixedSheet = SetEntrySheet(
      rowIndex: 0,
      draft: fixedFixture.draft,
      setNumber: 1,
      viewModel: fixedFixture.viewModel
    )

    #expect(pctSheet.weightValue == 0)
    #expect(fixedSheet.weightValue == 150)
  }

  @MainActor
  @Test func sheetDoesNotPrefillEmptyBarForUnsupportedIntensity() async throws {
    let fixture = try await makeSuggestionSheetFixture(
      seedHistory: true,
      prescribed: PrescribedSet(
        id: UUID(), setIndex: 0, intensity: .rir(2), loadMode: .rir, reps: 5)
    )
    let sheet = SetEntrySheet(
      rowIndex: 0,
      draft: fixture.draft,
      setNumber: 1,
      viewModel: fixture.viewModel
    )

    #expect(sheet.weightValue == 0)
  }
}

@MainActor
private struct SuggestionSheetFixture {
  let studentID: UUID
  let date: Date
  let e1rm: InMemoryE1RMRepository
  let viewModel: TodayWorkoutViewModel
  let draft: TodayWorkoutViewModel.SetRowDraft
  let historyPoint: E1RMHistoryPoint
}

private struct SuggestionSheetDomain {
  let studentID: UUID
  let date: Date
  let plan: StudentPlanView
  let historyPoint: E1RMHistoryPoint
}

@MainActor
private func makeSuggestionSheetFixture(
  seedHistory: Bool,
  prescribed: PrescribedSet? = nil
) async throws -> SuggestionSheetFixture {
  let domain = makeSuggestionSheetDomain(prescribed: prescribed)
  let e1rm = InMemoryE1RMRepository(
    seedPoints: seedHistory ? [domain.historyPoint] : []
  )
  let plans = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [domain.studentID: domain.plan])
  )
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: e1rm
  )
  await viewModel.load(date: domain.date, studentID: domain.studentID)
  let draft = try #require(viewModel.currentDrafts?.first)
  return SuggestionSheetFixture(
    studentID: domain.studentID,
    date: domain.date,
    e1rm: e1rm,
    viewModel: viewModel,
    draft: draft,
    historyPoint: domain.historyPoint
  )
}

private func makeSuggestionSheetDomain(prescribed: PrescribedSet? = nil) -> SuggestionSheetDomain {
  let studentID = UUID()
  let date = Date(timeIntervalSince1970: 1_780_000_000)
  let exercise = Exercise(
    id: UUID(),
    name: "深蹲",
    exerciseType: .mainLift,
    mainLiftFamily: .squat,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    movementPattern: [.squat],
    createdAt: date
  )
  let prescribed = prescribed ?? suggestionPrescription(setIndex: 0, reps: 5, rpe: 8)
  let planExercise = StudentPlanExercise(
    id: UUID(),
    exercise: exercise,
    sequenceIndex: 0,
    prescribedSets: [prescribed]
  )
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: date,
    days: [StudentPlanDay(id: UUID(), date: date, exercises: [planExercise])]
  )
  let historyPoint = E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: exercise.id,
    family: .squat,
    setLogId: UUID(),
    computedAt: date.addingTimeInterval(-60),
    e1RMKg: 120,
    sourceWeightKg: 100,
    sourceReps: 5,
    sourceRPE: 8
  )
  return SuggestionSheetDomain(
    studentID: studentID,
    date: date,
    plan: plan,
    historyPoint: historyPoint
  )
}

private func suggestionPrescription(
  setIndex: Int,
  reps: Int,
  rpe: Decimal
) -> PrescribedSet {
  PrescribedSet(id: UUID(), setIndex: setIndex, reps: reps, rpe: rpe)
}

private func suggestionDraft(
  exerciseID: UUID,
  prescribed: PrescribedSet,
  actualWeight: Decimal? = nil,
  completed: Bool = false,
  failed: Bool = false,
  isMainLift: Bool = true
) -> TodayWorkoutViewModel.SetRowDraft {
  TodayWorkoutViewModel.SetRowDraft(
    id: prescribed.id,
    planExerciseID: UUID(),
    exerciseID: exerciseID,
    exerciseName: "深蹲",
    isAccessory: false,
    isMainLift: isMainLift,
    prescribed: prescribed,
    actualWeight: actualWeight,
    completed: completed,
    failed: failed
  )
}
