import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

// spec 043 §G — the student read path projects PlanSet.coachNote onto
// PrescribedSet.coachNote so the cue reaches the student dashboard.
// The exercise-level note (PlanExercise.notes, the web 备注 column) must
// survive the same projection onto StudentPlanExercise.notes.

@Test func studentProjectionDropsCorruptZeroSetNumber() throws {
  // Dropping, not clamping: a clamp folds plan sets [0, 1] onto execution index 0 and the
  // (planExerciseID, setIndex) log key would make two cards share one log. See the CoachKit
  // twin test for the coexistence case; this fixture builder carries a single set, so here
  // the corrupt set must simply vanish rather than masquerade as the first set.
  let fixture = projectionFixture(setNumber: 0)

  let view = StudentPlanProjection.project(
    tree: fixture.tree,
    catalog: [fixture.catalogExercise],
    weekIndex: 1
  )

  #expect(view.days.first?.exercises.first?.prescribedSets.isEmpty == true)
}

@Test func studentProjectionUsesCanonicalSequenceOrder() throws {
  let fixture = projectionFixture(setNumber: 1)
  let lowerID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
  let higherID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
  let firstID = UUID()
  let lastID = UUID()
  let days = [
    PlanDay(
      id: lastID,
      planID: fixture.tree.plan.id,
      dayOfWeek: 1,
      weekNumber: 2,
      sortOrder: 0
    ),
    PlanDay(
      id: higherID,
      planID: fixture.tree.plan.id,
      dayOfWeek: 2,
      weekNumber: 1,
      sortOrder: 1
    ),
    PlanDay(
      id: lowerID,
      planID: fixture.tree.plan.id,
      dayOfWeek: 2,
      weekNumber: 1,
      sortOrder: 1
    ),
    PlanDay(
      id: firstID,
      planID: fixture.tree.plan.id,
      dayOfWeek: 1,
      weekNumber: 1,
      sortOrder: 0
    ),
  ]
  let tree = TrainingPlanTree(
    plan: fixture.tree.plan,
    days: days,
    exercises: [],
    sets: []
  )

  let projection = StudentPlanProjection.project(tree: tree, catalog: [], weekIndex: 1)

  #expect(projection.days.map(\.id) == [firstID, lowerID, higherID, lastID])
}

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
    notes: "D170/L190 递增5kg,顶组留一"
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

  let projectedExercise = try #require(view.days.first?.exercises.first)
  #expect(projectedExercise.notes == "D170/L190 递增5kg,顶组留一")

  let prescribed = projectedExercise.prescribedSets
  #expect(prescribed.count == 2)
  #expect(prescribed.map(\.setIndex) == [0, 1])
  #expect(prescribed[0].coachNote == "70%top")
  #expect(prescribed[1].coachNote == nil)
}

// swiftlint:disable:next function_body_length
private func projectionFixture(
  setNumber: Int
) -> (tree: TrainingPlanTree, catalogExercise: Exercise) {
  let planID = UUID()
  let dayID = UUID()
  let planExerciseID = UUID()
  let catalogID = UUID()
  let timestamp = Date(timeIntervalSince1970: 1_777_248_000)
  let plan = TrainingPlan(
    id: planID,
    coachID: UUID(),
    traineeID: UUID(),
    name: "防御测试计划",
    startDate: timestamp,
    endDate: timestamp.addingTimeInterval(604_800),
    planWeeks: 1,
    source: .coach,
    status: .published,
    createdAt: timestamp,
    updatedAt: timestamp
  )
  let day = PlanDay(
    id: dayID,
    planID: planID,
    dayOfWeek: 1,
    weekNumber: 1,
    sortOrder: 0
  )
  let planExercise = PlanExercise(
    id: planExerciseID,
    planDayID: dayID,
    exerciseID: catalogID,
    isMainLift: true,
    sortOrder: 0
  )
  let planSet = PlanSet(
    id: UUID(),
    planExerciseID: planExerciseID,
    setNumber: setNumber,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: 100,
    setType: .working,
    createdAt: timestamp
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
    createdAt: timestamp
  )
  return (
    TrainingPlanTree(
      plan: plan,
      days: [day],
      exercises: [planExercise],
      sets: [planSet]
    ),
    catalogExercise
  )
}
