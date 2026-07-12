import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func competitionLiftMigrationRebuildsSeriesAndClearsVariantPRBaseline() async throws {
  let fixture = makeMigrationFixture()
  let oldSeries = E1RMSeries.build(points: fixture.oldPoints, family: .squat)
  #expect(oldSeries.currentKg == 250)
  #expect(oldSeries.best?.valueKg == 250)
  #expect(try await fixture.e1rm.unacknowledgedPRs(studentId: fixture.studentID).count == 1)

  let first = try await fixture.migration.runIfNeeded(studentID: fixture.studentID)
  let rebuilt = try await fixture.e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseIds: fixture.catalog.map(\.id)
  )
  let points = rebuilt.values.flatMap { $0 }
  let rebuiltSeries = E1RMSeries.build(points: points, family: .squat)

  #expect(first == .init(didRun: true, pointCount: 2))
  #expect(Set(points.map(\.exerciseId)) == [fixture.genericSquat.id, fixture.lowBar.id])
  #expect(rebuilt[fixture.highBar.id]?.isEmpty == true)
  #expect(rebuilt[fixture.rdl.id]?.isEmpty == true)
  #expect(rebuiltSeries.rawEligible.count == 2)
  #expect(rebuiltSeries.currentKg == rebuiltSeries.best?.valueKg)
  #expect(rebuiltSeries.best?.valueKg != oldSeries.best?.valueKg)
  #expect(try await fixture.e1rm.unacknowledgedPRs(studentId: fixture.studentID).isEmpty)

  let second = try await fixture.migration.runIfNeeded(studentID: fixture.studentID)
  #expect(second == .init(didRun: false, pointCount: 0))
}

@Test func migrationResolvesLegacyPlanExerciseOnlyLog() async throws {
  let studentID = UUID()
  let exercise = migrationExercise(family: .bench, isCompetitionLift: true)
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: [])
  let plan = StudentPlanView(
    cycleID: UUID(), weekIndex: 1, startDate: Date(timeIntervalSince1970: 1_780_000_000),
    days: [
      StudentPlanDay(
        id: UUID(), date: Date(timeIntervalSince1970: 1_780_000_000), exercises: [slot])
    ])
  let log = migrationLog(
    studentID: studentID,
    planExerciseID: slot.id,
    weightKg: 100,
    date: Date(timeIntervalSince1970: 1_780_000_000)
  )
  let e1rm = InMemoryE1RMRepository()
  let migration = E1RMCompetitionLiftMigration(
    logs: InMemoryStudentTrainingLogRepository(seed: [log]),
    onboarding: InMemoryOnboardingRepository(studentId: studentID),
    plans: MigrationPlanRepository(plan: plan),
    catalogReader: nil,
    e1rm: e1rm,
    marker: InMemoryE1RMMigrationStore(),
    now: { Date(timeIntervalSince1970: 1_780_086_400) }
  )

  let result = try await migration.runIfNeeded(studentID: studentID)
  let points = try await e1rm.fetchHistory(studentId: studentID, exerciseId: exercise.id)
  #expect(result.pointCount == 1)
  #expect(points.first?.setLogId == log.id)
}

@Test func replacingHistoryPreservesOtherStudentsForBothRepositories() async throws {
  let otherStudentID = UUID()
  let migratedStudentID = UUID()
  let exercise = migrationExercise(family: .bench, isCompetitionLift: true)
  let date = Date(timeIntervalSince1970: 1_780_000_000)
  let repositories: [any E1RMRepository] = [
    InMemoryE1RMRepository(),
    LocalE1RMRepository(
      directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    ),
  ]

  for repository in repositories {
    let otherPoint = migrationPoint(
      studentID: otherStudentID, exerciseID: exercise.id, setLogID: UUID(), date: date, value: 120)
    let oldPoint = migrationPoint(
      studentID: migratedStudentID, exerciseID: exercise.id, setLogID: UUID(), date: date,
      value: 130)
    let replacement = migrationPoint(
      studentID: migratedStudentID, exerciseID: exercise.id, setLogID: UUID(), date: date,
      value: 140)
    try await repository.recordPoint(otherPoint)
    try await repository.recordPoint(oldPoint)
    try await repository.recordPR(
      PRBreakthroughEvent(
        id: UUID(), studentId: migratedStudentID, exerciseId: exercise.id,
        pointId: oldPoint.id, breakthroughE1RMKg: 130, previousMaxE1RMKg: 120,
        occurredAt: date, acknowledgedAt: nil))
    try await repository.replaceHistory(studentId: migratedStudentID, with: [replacement])

    #expect(
      try await repository.fetchHistory(studentId: otherStudentID, exerciseId: exercise.id)
        .map(\.e1RMKg) == [120])
    #expect(
      try await repository.fetchHistory(studentId: migratedStudentID, exerciseId: exercise.id)
        .map(\.e1RMKg) == [140])
    #expect(try await repository.unacknowledgedPRs(studentId: migratedStudentID).isEmpty)
  }
}

private struct MigrationFixture {
  let studentID: UUID
  let genericSquat: Exercise
  let lowBar: Exercise
  let highBar: Exercise
  let rdl: Exercise
  let catalog: [Exercise]
  let oldPoints: [E1RMHistoryPoint]
  let e1rm: InMemoryE1RMRepository
  let migration: E1RMCompetitionLiftMigration
}

private func makeMigrationFixture() -> MigrationFixture {
  let studentID = UUID()
  let genericSquat = migrationExercise(family: .squat, isCompetitionLift: true)
  let lowBar = migrationExercise(family: .squat, stance: .lowBar)
  let highBar = migrationExercise(family: .squat, stance: .highBar)
  let rdl = migrationExercise(family: .deadlift)
  let catalog = [genericSquat, lowBar, highBar, rdl]
  let anchor = Date(timeIntervalSince1970: 1_780_000_000)
  let logs = zip(catalog, [140, 130, 200, 220]).enumerated().map { offset, pair in
    migrationLog(
      studentID: studentID,
      planExerciseID: UUID(),
      weightKg: Decimal(pair.1),
      date: anchor.addingTimeInterval(Double(offset) * 86_400)
    )
  }
  let oldPoints = zip(logs, zip(catalog, [160.0, 150.0, 230.0, 250.0])).map { log, pair in
    migrationPoint(
      studentID: studentID, exerciseID: pair.0.id, setLogID: log.id,
      date: log.loggedAt, value: pair.1)
  }
  let oldPR = PRBreakthroughEvent(
    id: UUID(), studentId: studentID, exerciseId: rdl.id, pointId: oldPoints[3].id,
    breakthroughE1RMKg: 250, previousMaxE1RMKg: 0,
    occurredAt: oldPoints[3].computedAt, acknowledgedAt: nil)
  let e1rm = InMemoryE1RMRepository(seedPoints: oldPoints, seedPRs: [oldPR])
  let migration = E1RMCompetitionLiftMigration(
    logs: InMemoryStudentTrainingLogRepository(seed: logs),
    onboarding: InMemoryOnboardingRepository(
      studentId: studentID,
      seed: OnboardingProfile(
        userId: studentID, squatStance: .lowBar, deadliftStyle: .conventional,
        createdAt: anchor, updatedAt: anchor)),
    plans: MigrationPlanRepository(),
    catalogReader: MigrationCatalogReader(exercises: catalog),
    e1rm: e1rm,
    marker: InMemoryE1RMMigrationStore(),
    now: { anchor.addingTimeInterval(4 * 86_400) }
  )
  return MigrationFixture(
    studentID: studentID, genericSquat: genericSquat, lowBar: lowBar,
    highBar: highBar, rdl: rdl, catalog: catalog, oldPoints: oldPoints,
    e1rm: e1rm, migration: migration)
}

private func migrationExercise(
  family: LiftFamily,
  stance: CompetitionStance? = nil,
  isCompetitionLift: Bool = false
) -> Exercise {
  Exercise(
    id: UUID(), name: "测试动作",
    exerciseType: stance == nil ? .mainLiftVariation : .mainLift,
    mainLiftFamily: family, isCompetitionLift: isCompetitionLift,
    competitionStance: stance, muscleGroups: [], equipment: [],
    createdAt: Date(timeIntervalSince1970: 0))
}

private func migrationLog(
  studentID: UUID,
  planExerciseID: UUID,
  weightKg: Decimal,
  date: Date
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(), studentID: studentID, planExerciseID: planExerciseID,
    setIndex: 0, loggedAt: date, weightKg: weightKg, reps: 5, rpe: 8,
    completed: true)
}

private func migrationPoint(
  studentID: UUID,
  exerciseID: UUID,
  setLogID: UUID,
  date: Date,
  value: Double
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(), studentId: studentID, exerciseId: exerciseID, setLogId: setLogID,
    computedAt: date, e1RMKg: value, sourceWeightKg: value * 0.88,
    sourceReps: 5, sourceRPE: 8)
}

private struct MigrationCatalogReader: ExerciseCatalogReading {
  let exercises: [Exercise]
  func fetchExerciseCatalog() async throws -> [Exercise] { exercises }
}

private struct MigrationPlanRepository: StudentPlanRepository {
  let plan: StudentPlanView?
  init(plan: StudentPlanView? = nil) { self.plan = plan }
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { plan }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { nil }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { plan?.days ?? [] }
}
