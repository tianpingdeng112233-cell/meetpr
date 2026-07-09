import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

// spec 043 §G — the student read path projects PlanSet.coachNote onto
// PrescribedSet.coachNote so the cue reaches the student dashboard.

// swiftlint:disable:next function_body_length
@Test func projectionCarriesCoachNoteOntoPrescribedSet() throws {
  let planID = UUID()
  let dayID = UUID()
  let exerciseID = UUID()
  let catalogID = UUID()

  let plan = TrainingPlan(
    id: planID,
    coachID: UUID(),
    traineeID: UUID(),
    name: "导入计划",
    startDate: Date(timeIntervalSince1970: 1_777_248_000),
    endDate: Date(timeIntervalSince1970: 1_777_852_800),
    planWeeks: 1,
    source: .coach,
    status: .published,
    blockType: "hypertrophy",
    mesocyclePhase: "accumulation",
    trainingMax: Decimal(string: "92.5"),
    tmSetAt: Date(timeIntervalSince1970: 1_783_036_800),
    createdAt: Date(timeIntervalSince1970: 1_777_248_000),
    updatedAt: Date(timeIntervalSince1970: 1_777_248_000)
  )
  let day = PlanDay(id: dayID, planID: planID, dayOfWeek: 1, weekNumber: 1, sortOrder: 0)
  let exercise = PlanExercise(
    id: exerciseID,
    planDayID: dayID,
    exerciseID: catalogID,
    isMainLift: true,
    sortOrder: 0,
    notes: nil
  )
  let setWithNote = PlanSet(
    id: UUID(),
    planExerciseID: exerciseID,
    setNumber: 1,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: Decimal(string: "100")!,
    setType: .working,
    coachNote: "70%top",
    createdAt: Date(timeIntervalSince1970: 1_777_248_000)
  )
  let setWithoutNote = PlanSet(
    id: UUID(),
    planExerciseID: exerciseID,
    setNumber: 2,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: Decimal(string: "105")!,
    setType: .working,
    createdAt: Date(timeIntervalSince1970: 1_777_248_000)
  )
  let catalogExercise = Exercise(
    id: catalogID,
    name: "低杆深蹲",
    exerciseType: .mainLift,
    mainLiftFamily: .squat,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    movementPattern: [.squat],
    createdByCoachID: nil,
    createdAt: Date(timeIntervalSince1970: 1_777_248_000)
  )

  let tree = TrainingPlanTree(
    plan: plan,
    days: [day],
    exercises: [exercise],
    sets: [setWithNote, setWithoutNote]
  )

  let view = StudentPlanProjection.project(tree: tree, catalog: [catalogExercise], weekIndex: 1)

  let prescribed = try #require(view.days.first?.exercises.first?.prescribedSets)
  #expect(prescribed.count == 2)
  #expect(prescribed[0].coachNote == "70%top")
  #expect(prescribed[1].coachNote == nil)
  #expect(view.blockType == "hypertrophy")
  #expect(view.mesocyclePhase == "accumulation")
  #expect(view.trainingMax == Decimal(string: "92.5"))
  #expect(view.tmSetAt == Date(timeIntervalSince1970: 1_783_036_800))
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func todayWorkoutContextCarriesAlgorithmMetadata() throws {
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: Date(timeIntervalSince1970: 1_783_036_800),
    blockType: "peaking",
    mesocyclePhase: "realization",
    trainingMax: Decimal(90),
    tmSetAt: Date(timeIntervalSince1970: 1_783_036_800),
    days: []
  )

  let context = try #require(
    TodayWorkoutViewModel.planContext(from: plan, selectedDate: plan.startDate)
  )
  let badges = context.algorithmMetadata.badges(now: plan.startDate)

  #expect(badges.map(\.title) == ["巅峰块", "实现", "训练最大值 ≈ 0.9×1RM 90kg"])
}
