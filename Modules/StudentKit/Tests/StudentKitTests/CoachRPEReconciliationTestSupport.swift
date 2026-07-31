import CoreModels
import Foundation
import RepositoryContracts

@testable import StudentKit

struct CoachRPEFixture: Sendable {
  let studentID: UUID
  let exercise: Exercise
  let planExerciseID: UUID
  let plan: StudentPlanView
  let onboarding: InMemoryOnboardingRepository
  let plans: CoachRPEPlanRepository
  let anchor: Date
}

func makeCoachRPEFixture(
  prescribedSets: [PrescribedSet] = []
) -> CoachRPEFixture {
  let studentID = UUID()
  let anchor = Date(timeIntervalSince1970: 1_780_000_000)
  let exercise = Exercise(
    id: UUID(),
    name: "卧推",
    exerciseType: .mainLift,
    mainLiftFamily: .bench,
    isCompetitionLift: true,
    muscleGroups: [],
    equipment: [],
    createdAt: anchor
  )
  let planExerciseID = UUID()
  let planExercise = StudentPlanExercise(
    id: planExerciseID,
    exercise: exercise,
    sequenceIndex: 0,
    prescribedSets: prescribedSets
  )
  let day = StudentPlanDay(id: UUID(), date: anchor, exercises: [planExercise])
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: anchor,
    days: [day]
  )
  return CoachRPEFixture(
    studentID: studentID,
    exercise: exercise,
    planExerciseID: planExerciseID,
    plan: plan,
    onboarding: InMemoryOnboardingRepository(studentId: studentID),
    plans: CoachRPEPlanRepository(plan: plan),
    anchor: anchor
  )
}

func makeCoachRPEReconciler(
  fixture: CoachRPEFixture,
  logs: any StudentTrainingLogRepository,
  e1rm: any E1RMRepository
) -> E1RMCoachRPEReconciler {
  E1RMCoachRPEReconciler(
    logs: logs,
    onboarding: fixture.onboarding,
    plans: fixture.plans,
    catalogReader: nil,
    e1rm: e1rm,
    now: { fixture.anchor.addingTimeInterval(86_400) }
  )
}

func coachRPELog(
  fixture: CoachRPEFixture,
  setIndex: Int = 0,
  weightKg: Decimal,
  rpe: Decimal,
  date: Date
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: fixture.studentID,
    planExerciseID: fixture.planExerciseID,
    exerciseID: fixture.exercise.id,
    setIndex: setIndex,
    loggedAt: date,
    weightKg: weightKg,
    reps: 5,
    rpe: rpe,
    completed: true
  )
}

func replacingCoachRPE(
  in log: StudentSetLog,
  with coachRPE: Decimal?
) -> StudentSetLog {
  StudentSetLog(
    id: log.id,
    studentID: log.studentID,
    planExerciseID: log.planExerciseID,
    exerciseID: log.exerciseID,
    setIndex: log.setIndex,
    loggedAt: log.loggedAt,
    weightKg: log.weightKg,
    reps: log.reps,
    rpe: log.rpe,
    coachRPE: coachRPE,
    completed: log.completed,
    failed: log.failed,
    assumed: log.assumed
  )
}

func recordCoachRPEPoint(
  log: StudentSetLog,
  fixture: CoachRPEFixture,
  in e1rm: any E1RMRepository
) async {
  let recorder = E1RMRecorder(e1rm: e1rm, now: { log.loggedAt })
  _ = await recorder.record(
    E1RMRecorder.Input(
      studentID: fixture.studentID,
      exerciseID: fixture.exercise.id,
      family: .bench,
      setLogID: log.id,
      weightKg: log.weightKg,
      reps: log.reps,
      rpe: log.rpe,
      coachRPE: log.coachRPE,
      completed: true,
      failed: false
    )
  )
}

struct CoachRPEPlanRepository: StudentPlanRepository {
  let plan: StudentPlanView

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { plan }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    plan.days.first
  }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { plan.days }
}
