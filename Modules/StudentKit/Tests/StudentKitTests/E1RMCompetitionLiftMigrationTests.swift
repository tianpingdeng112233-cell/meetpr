import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func competitionLiftMigrationRebuildsSeriesAndClearsVariantPRBaseline() async throws {
  let fixture = makeMigrationFixture()

  let oldSquatSeries = E1RMSeries.build(
    points: Array(fixture.oldPoints.prefix(3)), family: .squat)
  #expect(oldSquatSeries.currentKg == 230)
  #expect(oldSquatSeries.best?.valueKg == 230)
  #expect(try await fixture.e1rm.unacknowledgedPRs(studentId: fixture.studentID).count == 1)

  let first = try await fixture.migration.runIfNeeded(studentID: fixture.studentID)
  let rebuilt = try await fixture.e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseIds: fixture.catalog.map(\.id)
  )
  let rebuiltPoints = rebuilt.values.flatMap { $0 }
  let rebuiltSquatSeries = E1RMSeries.build(points: rebuiltPoints, family: .squat)

  #expect(first == .init(didRun: true, pointCount: 2))
  #expect(
    Set(rebuiltPoints.map(\.exerciseId)) == [fixture.genericSquat.id, fixture.lowBar.id])
  #expect(rebuilt[fixture.highBar.id]?.isEmpty == true)
  #expect(rebuilt[fixture.rdl.id]?.isEmpty == true)
  #expect(rebuiltSquatSeries.rawEligible.count == 2)
  #expect(rebuiltSquatSeries.currentKg == rebuiltSquatSeries.best?.valueKg)
  #expect(rebuiltSquatSeries.best?.valueKg != oldSquatSeries.best?.valueKg)
  #expect(try await fixture.e1rm.unacknowledgedPRs(studentId: fixture.studentID).isEmpty)

  let second = try await fixture.migration.runIfNeeded(studentID: fixture.studentID)
  let afterSecondRun = try await fixture.e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseIds: fixture.catalog.map(\.id)
  )
  #expect(second == .init(didRun: false, pointCount: 0))
  #expect(afterSecondRun.values.flatMap { $0 }.count == 2)
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

private struct MigrationExerciseSet {
  let genericSquat: Exercise
  let lowBar: Exercise
  let highBar: Exercise
  let rdl: Exercise

  var catalog: [Exercise] { [genericSquat, lowBar, highBar, rdl] }
}

private func makeMigrationFixture() -> MigrationFixture {
  let studentID = UUID()
  let exercises = MigrationExerciseSet(
    genericSquat: migrationExercise(family: .squat, isCompetitionLift: true),
    lowBar: migrationExercise(family: .squat, stance: .lowBar),
    highBar: migrationExercise(family: .squat, stance: .highBar),
    rdl: migrationExercise(family: .deadlift)
  )
  let anchor = Date(timeIntervalSince1970: 1_780_000_000)
  let setLogs = migrationLogs(studentID: studentID, exercises: exercises, anchor: anchor)
  let oldPoints = zip(setLogs, [160.0, 150.0, 230.0, 250.0]).map { log, value in
    migrationPoint(log: log, valueKg: value)
  }
  let oldPR = PRBreakthroughEvent(
    id: UUID(), studentId: studentID, exerciseId: exercises.rdl.id,
    pointId: oldPoints[3].id,
    breakthroughE1RMKg: oldPoints[3].e1RMKg, previousMaxE1RMKg: 0,
    occurredAt: oldPoints[3].computedAt, acknowledgedAt: nil)
  let e1rm = InMemoryE1RMRepository(seedPoints: oldPoints, seedPRs: [oldPR])
  let onboarding = InMemoryOnboardingRepository(
    studentId: studentID,
    seed: OnboardingProfile(
      userId: studentID, squatStance: .lowBar, deadliftStyle: .conventional,
      createdAt: anchor, updatedAt: anchor))
  let migration = E1RMCompetitionLiftMigration(
    logs: InMemoryStudentTrainingLogRepository(seed: setLogs), onboarding: onboarding,
    plans: MigrationPlanRepository(), catalogReader: nil,
    fallbackCatalog: exercises.catalog,
    e1rm: e1rm, marker: InMemoryE1RMMigrationStore(),
    now: { anchor.addingTimeInterval(4 * 86_400) })
  return MigrationFixture(
    studentID: studentID, genericSquat: exercises.genericSquat, lowBar: exercises.lowBar,
    highBar: exercises.highBar, rdl: exercises.rdl, catalog: exercises.catalog,
    oldPoints: oldPoints,
    e1rm: e1rm, migration: migration)
}

private func migrationLogs(
  studentID: UUID,
  exercises: MigrationExerciseSet,
  anchor: Date
) -> [StudentSetLog] {
  [
    migrationLog(
      studentID: studentID, exercise: exercises.genericSquat, weightKg: 140, date: anchor),
    migrationLog(
      studentID: studentID, exercise: exercises.lowBar, weightKg: 130,
      date: anchor.addingTimeInterval(86_400)),
    migrationLog(
      studentID: studentID, exercise: exercises.highBar, weightKg: 200,
      date: anchor.addingTimeInterval(2 * 86_400)),
    migrationLog(
      studentID: studentID, exercise: exercises.rdl, weightKg: 220,
      date: anchor.addingTimeInterval(3 * 86_400)),
  ]
}

@Test func replacingHistoryPreservesOtherStudentsForBothRepositories() async throws {
  let otherStudentID = UUID()
  let migratedStudentID = UUID()
  let exercise = migrationExercise(family: .bench, isCompetitionLift: true)
  let otherLog = migrationLog(
    studentID: otherStudentID,
    exercise: exercise,
    weightKg: 100,
    date: Date(timeIntervalSince1970: 1_780_000_000)
  )
  let migratedLog = migrationLog(
    studentID: migratedStudentID,
    exercise: exercise,
    weightKg: 110,
    date: Date(timeIntervalSince1970: 1_780_000_000)
  )
  let repositories: [any E1RMRepository] = [
    InMemoryE1RMRepository(),
    LocalE1RMRepository(
      directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    ),
  ]

  for repository in repositories {
    let oldMigratedPoint = migrationPoint(log: migratedLog, valueKg: 130)
    try await repository.recordPoint(migrationPoint(log: otherLog, valueKg: 120))
    try await repository.recordPoint(oldMigratedPoint)
    try await repository.recordPR(
      PRBreakthroughEvent(
        id: UUID(),
        studentId: migratedStudentID,
        exerciseId: exercise.id,
        pointId: oldMigratedPoint.id,
        breakthroughE1RMKg: 130,
        previousMaxE1RMKg: 120,
        occurredAt: oldMigratedPoint.computedAt,
        acknowledgedAt: nil
      ))
    try await repository.replaceHistory(
      studentId: migratedStudentID,
      with: [migrationPoint(log: migratedLog, valueKg: 140)]
    )

    let other = try await repository.fetchHistory(
      studentId: otherStudentID, exerciseId: exercise.id)
    let migrated = try await repository.fetchHistory(
      studentId: migratedStudentID, exerciseId: exercise.id)
    #expect(other.map(\.e1RMKg) == [120])
    #expect(migrated.map(\.e1RMKg) == [140])
    #expect(try await repository.unacknowledgedPRs(studentId: migratedStudentID).isEmpty)
  }
}

@Test func migrationResolvesLegacyCoachedLogThroughPlanExerciseID() async throws {
  let studentID = UUID()
  let exercise = migrationExercise(family: .squat, isCompetitionLift: true)
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: [])
  let plan = StudentPlanView(
    cycleID: UUID(), weekIndex: 1, startDate: Date(timeIntervalSince1970: 1_780_000_000),
    days: [
      StudentPlanDay(
        id: UUID(), date: Date(timeIntervalSince1970: 1_780_000_000), exercises: [slot])
    ])
  let log = StudentSetLog(
    id: UUID(), studentID: studentID, planExerciseID: slot.id, exerciseID: nil,
    setIndex: 0, loggedAt: Date(timeIntervalSince1970: 1_780_000_000),
    weightKg: 140, reps: 5, rpe: 8, completed: true)
  let e1rm = InMemoryE1RMRepository()
  let migration = E1RMCompetitionLiftMigration(
    logs: InMemoryStudentTrainingLogRepository(seed: [log]),
    onboarding: InMemoryOnboardingRepository(studentId: studentID),
    plans: MigrationPlanRepository(plan: plan), catalogReader: nil,
    fallbackCatalog: [exercise], e1rm: e1rm, marker: InMemoryE1RMMigrationStore(),
    now: { Date(timeIntervalSince1970: 1_780_086_400) })

  let result = try await migration.runIfNeeded(studentID: studentID)
  let points = try await e1rm.fetchHistory(studentId: studentID, exerciseId: exercise.id)
  #expect(result.pointCount == 1)
  #expect(points.first?.setLogId == log.id)
}

private func migrationExercise(
  family: LiftFamily,
  stance: CompetitionStance? = nil,
  isCompetitionLift: Bool = false
) -> Exercise {
  Exercise(
    id: UUID(),
    name: "测试动作",
    exerciseType: stance == nil ? .mainLiftVariation : .mainLift,
    mainLiftFamily: family,
    isCompetitionLift: isCompetitionLift,
    competitionStance: stance,
    muscleGroups: [],
    equipment: [],
    createdAt: Date(timeIntervalSince1970: 0)
  )
}

private func migrationLog(
  studentID: UUID,
  exercise: Exercise,
  weightKg: Decimal,
  date: Date
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: nil,
    exerciseID: exercise.id,
    loggedDate: date.formatted(.iso8601.year().month().day()),
    adhoc: true,
    setIndex: 0,
    loggedAt: date,
    weightKg: weightKg,
    reps: 5,
    rpe: 8,
    completed: true
  )
}

private func migrationPoint(log: StudentSetLog, valueKg: Double) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: log.studentID,
    exerciseId: log.exerciseID ?? UUID(),
    setLogId: log.id,
    computedAt: log.loggedAt,
    e1RMKg: valueKg,
    sourceWeightKg: NSDecimalNumber(decimal: log.weightKg).doubleValue,
    sourceReps: log.reps,
    sourceRPE: log.rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
  )
}

private struct MigrationPlanRepository: StudentPlanRepository {
  let plan: StudentPlanView?

  init(plan: StudentPlanView? = nil) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { plan }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { nil }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { [] }
}
