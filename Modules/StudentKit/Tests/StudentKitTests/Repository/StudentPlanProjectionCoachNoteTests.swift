import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

// spec 043 §G — the student read path projects PlanSet.coachNote onto
// PrescribedSet.coachNote so the cue reaches the student dashboard.
// The exercise-level note (PlanExercise.notes, the web 备注 column) must
// survive the same projection onto StudentPlanExercise.notes.

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
  #expect(prescribed[0].coachNote == "70%top")
  #expect(prescribed[1].coachNote == nil)
}
