import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

@Suite struct PctProjectionStopgapTests {
  @MainActor
  @Test func pctRPEProjectionOmitsPseudoRPEAndLeavesTodayRowWeightEmpty() throws {
    let fixture = makeProjection(loadMode: "pct", intensityMode: .rpe, targetValue: 6)
    let prescribed = try #require(
      fixture.plan.days.first?.exercises.first?.prescribedSets.first)

    #expect(prescribed.weightKg == nil)
    #expect(prescribed.rpe == nil)

    let draft = try #require(
      TodayWorkoutViewModel.makeDrafts(
        for: fixture.plan.days[0],
        existingLogs: []
      ).first)
    let row = TodayWorkoutPresentation.record(from: draft, index: 1, videoState: .none)

    #expect(draft.actualWeight == nil)
    #expect(row.weight == nil)
  }

  @MainActor
  @Test func pctRPEProjectionDisablesSuggestionAndSeedsSheetAtWeightFloor() async throws {
    let fixture = makeProjection(loadMode: "pct", intensityMode: .rpe, targetValue: 6)
    let history = E1RMHistoryPoint(
      id: UUID(),
      studentId: fixture.studentID,
      exerciseId: fixture.exerciseID,
      family: .squat,
      setLogId: UUID(),
      computedAt: fixture.date.addingTimeInterval(-60),
      e1RMKg: 200,
      sourceWeightKg: 170,
      sourceReps: 5,
      sourceRPE: 10
    )
    let viewModel = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [fixture.studentID: fixture.plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(),
      e1rm: InMemoryE1RMRepository(seedPoints: [history])
    )

    await viewModel.load(date: fixture.date, studentID: fixture.studentID)
    let draft = try #require(viewModel.currentDrafts?.first)
    let outcome = viewModel.weightSuggestionOutcome(forSetID: draft.id)
    let sheet = SetEntrySheet(
      rowIndex: 0,
      draft: draft,
      setNumber: 1,
      viewModel: viewModel
    )

    #expect(draft.prescribed.rpe == nil)
    #expect(outcome.suggestion == nil)
    #expect(outcome.unavailableReason == .missingPrescribedRPE)
    #expect(sheet.suggestionOutcomeSnapshot.unavailableReason == .missingPrescribedRPE)
    #expect(sheet.weightValue == 20)
  }

  @Test func responseWithoutLoadModePreservesRPEProjection() throws {
    let fixture = makeProjection(loadMode: nil, intensityMode: .rpe, targetValue: 8)
    let prescribed = try #require(
      fixture.plan.days.first?.exercises.first?.prescribedSets.first)

    #expect(prescribed.weightKg == nil)
    #expect(prescribed.rpe == 8)
  }

  @Test(arguments: ["rpe", "rir", "rpe_range", "future_mode"])
  func nonPctLoadModesPreserveRPEProjection(loadMode: String) throws {
    let fixture = makeProjection(loadMode: loadMode, intensityMode: .rpe, targetValue: 8)
    let prescribed = try #require(
      fixture.plan.days.first?.exercises.first?.prescribedSets.first)

    #expect(prescribed.rpe == 8)
  }

  @Test func pctWeightProjectionPreservesTargetWeight() throws {
    let fixture = makeProjection(loadMode: "pct", intensityMode: .weight, targetValue: 120)
    let prescribed = try #require(
      fixture.plan.days.first?.exercises.first?.prescribedSets.first)

    #expect(prescribed.weightKg == 120)
    #expect(prescribed.rpe == nil)
  }
}

private struct PctProjectionFixture {
  let studentID: UUID
  let exerciseID: UUID
  let date: Date
  let plan: StudentPlanView
}

// swiftlint:disable:next function_body_length
private func makeProjection(
  loadMode: String?,
  intensityMode: IntensityMode,
  targetValue: Decimal
) -> PctProjectionFixture {
  let studentID = UUID()
  let planID = UUID()
  let dayID = UUID()
  let planExerciseID = UUID()
  let exerciseID = UUID()
  let date = Date(timeIntervalSince1970: 1_780_000_000)
  let tree = TrainingPlanTree(
    plan: TrainingPlan(
      id: planID,
      coachID: UUID(),
      traineeID: studentID,
      name: "百分比止血测试",
      startDate: date,
      endDate: date.addingTimeInterval(604_800),
      planWeeks: 1,
      source: .coach,
      status: .published,
      createdAt: date,
      updatedAt: date
    ),
    days: [
      PlanDay(id: dayID, planID: planID, dayOfWeek: 1, weekNumber: 1, sortOrder: 0)
    ],
    exercises: [
      PlanExercise(
        id: planExerciseID,
        planDayID: dayID,
        exerciseID: exerciseID,
        isMainLift: true,
        sortOrder: 0
      )
    ],
    sets: [
      PlanSet(
        id: UUID(),
        planExerciseID: planExerciseID,
        setNumber: 1,
        targetReps: 5,
        intensityMode: intensityMode,
        targetValue: targetValue,
        loadMode: loadMode,
        setType: .working,
        createdAt: date
      )
    ]
  )
  let exercise = Exercise(
    id: exerciseID,
    name: "深蹲",
    exerciseType: .mainLift,
    mainLiftFamily: .squat,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    movementPattern: [.squat],
    createdAt: date
  )
  let plan = StudentPlanProjection.project(tree: tree, catalog: [exercise], weekIndex: 1)
  return PctProjectionFixture(
    studentID: studentID,
    exerciseID: exerciseID,
    date: date,
    plan: plan
  )
}
