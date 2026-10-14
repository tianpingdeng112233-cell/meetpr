import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func planOnlyCatalogKeepsAddedNamesOnFirstLoad() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let exercise = try #require(plan.days.last?.exercises.last?.exercise)
  let log = StudentAddedSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planDayID: plan.days[0].id,
    exerciseID: exercise.id, setIndex: 0, loggedAt: Date(), weightKg: 30, reps: 10,
    completed: true)
  let model = TodayWorkoutViewModel(
    plans: PlanOnlyAddedCatalog(plan: plan),
    logs: InMemoryStudentTrainingLogRepository(added: [log]))
  await model.load(
    dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID, preloadedPlan: plan)
  #expect(model.currentDrafts?.first(where: \.isStudentAdded)?.exerciseName == exercise.name)
}

@MainActor
@Test func catalogFailurePreservesAddedRowsAndNextLoadRestoresTheirNames() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let exercise = Exercise(
    id: UUID(), name: "测试加练", nameEn: "Added test", exerciseType: .accessory,
    isCompetitionLift: false, muscleGroups: [], equipment: [], createdAt: Date())
  let plans = RecoveringAddedCatalog(plan: plan, exercise: exercise)
  let log = StudentAddedSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planDayID: plan.days[0].id,
    exerciseID: exercise.id, setIndex: 0, loggedAt: Date(), weightKg: 40, reps: 8,
    completed: true)
  let model = TodayWorkoutViewModel(
    plans: plans, logs: InMemoryStudentTrainingLogRepository(added: [log]))
  await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
  #expect(model.currentDrafts?.first(where: \.isStudentAdded)?.loggedSetID == log.id)
  await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
  #expect(model.currentDrafts?.first(where: \.isStudentAdded)?.exerciseName == exercise.name)
}

@MainActor
@Test func unavailableCatalogCannotEraseHistoricalWeightBaseline() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let student = StudentDemoSeed.studentID
  let exercise = Exercise(
    id: UUID(), name: "旧动作", exerciseType: .mainLiftVariation,
    mainLiftFamily: .bench, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdAt: Date())
  let log = StudentAddedSetLog(
    id: UUID(), studentID: student, planDayID: plan.days[0].id,
    exerciseID: exercise.id, setIndex: 0, loggedAt: Date(), weightKg: 100, reps: 3,
    rpe: 8, completed: true)
  let e1rm = InMemoryE1RMRepository()
  await StudentAddedHistory.record([log], catalog: [exercise], e1rm: e1rm, profile: nil)
  let model = TodayWorkoutViewModel(
    plans: RecoveringAddedCatalog(plan: plan, exercise: exercise),
    logs: CompleteAddedLedger(log: log), e1rm: e1rm)
  await model.load(dayID: plan.days[0].id, studentID: student)
  #expect(try await e1rm.fetchWeightBaselines(studentId: student).first?.maxWeightKg == 100)
  await model.load(dayID: plan.days[0].id, studentID: student)
  #expect(try await e1rm.fetchWeightBaselines(studentId: student).first?.maxWeightKg == 100)
}

private struct CompleteAddedLedger: StudentAddedLogRepository {
  let log: StudentAddedSetLog
  func fetchAllLogs(studentID: UUID, in range: ClosedRange<Date>) async throws -> StudentWorkoutLogs
  {
    StudentWorkoutLogs(planned: [], added: [log], isCompleteLedger: true)
  }
  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    []
  }
  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) async throws -> [StudentSetLog] {
    []
  }
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog { log }
  func recordAddedSet(_ log: StudentAddedSetLog) async throws -> StudentAddedSetLog { log }
  func deleteAddedSet(id: UUID, studentID: UUID) async throws {}
}

private actor RecoveringAddedCatalog: StudentPlanRepository, ExerciseCatalogReading {
  let plan: StudentPlanView
  let exercise: Exercise
  var first = true
  init(plan: StudentPlanView, exercise: Exercise) {
    self.plan = plan
    self.exercise = exercise
  }
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { plan }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { plan.days.first }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { plan.days }
  func fetchExerciseCatalog() async throws -> [Exercise] {
    if first {
      first = false
      throw URLError(.notConnectedToInternet)
    }
    return plan.days.flatMap(\.exercises).map(\.exercise) + [exercise]
  }
}

private struct PlanOnlyAddedCatalog: StudentPlanRepository {
  let plan: StudentPlanView
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { plan }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { plan.days.first }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { plan.days }
}
