import CoachKit
import CoreModels
import Foundation
import StudentKit
import Testing

@testable import AppShell

/// Same-process acceptance check for spec 024 §技术要求 (acceptance item: 教练 publish
/// → 学员 fetch via the shared store). The coach repo runs the publish-side mapper and
/// writes a projection into `InMemoryPlanStore`; the student repo reads it back. This is
/// the only coverage that exercises the real CoachKit + AppShell + StudentKit composition
/// (each module's own tests use a spy/standalone store).
@available(iOS 17.0, macOS 14.0, *)
@Test func coachPublishProjectionIsReadableByStudentFetchViaSharedStore() async throws {
  let store = InMemoryPlanStore()
  let coach = InMemoryPlanRepository(
    students: [],
    catalog: [ProjectionIntegrationFixture.exercise],
    store: store
  )
  let student = InMemoryStudentPlanRepository(store: store)

  try await coach.publishPlan(
    plan: ProjectionIntegrationFixture.plan,
    days: [ProjectionIntegrationFixture.day],
    exercises: [ProjectionIntegrationFixture.planExercise],
    sets: [ProjectionIntegrationFixture.planSet]
  )

  let fetched = try await student.fetchCurrentPlan(
    studentID: ProjectionIntegrationFixture.studentID)

  let view = try #require(fetched)
  #expect(view.cycleID == ProjectionIntegrationFixture.planID)
  let exercise = try #require(view.days.first?.exercises.first)
  #expect(exercise.exercise.id == ProjectionIntegrationFixture.exerciseID)
  #expect(exercise.prescribedSets.first?.weightKg == Decimal(100))
}

@available(iOS 17.0, macOS 14.0, *)
private enum ProjectionIntegrationFixture {
  static let now = Date(timeIntervalSince1970: 1_766_630_400)
  static let planID = uuid(1)
  static let studentID = uuid(2)
  static let coachID = uuid(3)
  static let exerciseID = uuid(30)
  static let dayID = uuid(50)
  static let planExerciseID = uuid(60)

  static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }

  static let exercise = Exercise(
    id: exerciseID,
    name: "深蹲",
    exerciseType: .mainLift,
    mainLiftFamily: .squat,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    movementPattern: [.squat],
    createdAt: now
  )

  static let plan = TrainingPlan(
    id: planID,
    coachID: coachID,
    traineeID: studentID,
    name: "集成测试计划",
    startDate: now,
    endDate: now.addingTimeInterval(7 * 86_400),
    planWeeks: 1,
    source: .coach,
    status: .published,
    createdAt: now,
    updatedAt: now
  )

  static let day = PlanDay(id: dayID, planID: planID, dayOfWeek: 1, weekNumber: 1, sortOrder: 0)

  static let planExercise = PlanExercise(
    id: planExerciseID,
    planDayID: dayID,
    exerciseID: exerciseID,
    isMainLift: true,
    sortOrder: 0
  )

  static let planSet = PlanSet(
    id: uuid(80),
    planExerciseID: planExerciseID,
    setNumber: 1,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: Decimal(100),
    setType: .working,
    createdAt: now
  )
}
