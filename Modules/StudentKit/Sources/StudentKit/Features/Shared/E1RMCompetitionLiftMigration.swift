import CoreModels
import Foundation
import RepositoryContracts

protocol E1RMMigrationStoring: Sendable {
  func isCompleted(studentID: UUID) async -> Bool
  func markCompleted(studentID: UUID) async
}

actor UserDefaultsE1RMMigrationStore: E1RMMigrationStoring {
  private static let version = "competition-lift-resolver-v1"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func isCompleted(studentID: UUID) -> Bool {
    defaults.bool(forKey: key(studentID: studentID))
  }

  func markCompleted(studentID: UUID) {
    defaults.set(true, forKey: key(studentID: studentID))
  }

  private func key(studentID: UUID) -> String {
    "e1rm-migration.\(Self.version).\(studentID.uuidString.lowercased())"
  }
}

/// One-shot student-side rebuild after the competition-lift gate changed.
/// Canonical set logs are replayed chronologically through the release/1.0
/// recorder, then replace this student's local history in one repository
/// operation. Historical PR events are discarded so removed variations cannot
/// remain a PR baseline.
actor E1RMCompetitionLiftMigration {
  private struct CatalogContext: Sendable {
    let exercises: [Exercise]
    let exerciseIDByPlanExerciseID: [UUID: UUID]
  }

  private struct ReplayContext: Sendable {
    let profile: OnboardingProfile?
    let exerciseByID: [UUID: Exercise]
    let exerciseIDByPlanExerciseID: [UUID: UUID]
    let oldExerciseIDBySetLogID: [UUID: UUID]
  }

  struct Result: Equatable, Sendable {
    let didRun: Bool
    let pointCount: Int
  }

  private let logs: any StudentTrainingLogRepository
  private let onboarding: any OnboardingProfileReading
  private let plans: any StudentPlanRepository
  private let catalogReader: (any ExerciseCatalogReading)?
  private let e1rm: any E1RMRepository
  private let marker: any E1RMMigrationStoring
  private let now: @Sendable () -> Date

  init(
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    plans: any StudentPlanRepository,
    catalogReader: (any ExerciseCatalogReading)?,
    e1rm: any E1RMRepository,
    marker: any E1RMMigrationStoring = UserDefaultsE1RMMigrationStore(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.logs = logs
    self.onboarding = onboarding
    self.plans = plans
    self.catalogReader = catalogReader
    self.e1rm = e1rm
    self.marker = marker
    self.now = now
  }

  func runIfNeeded(studentID: UUID) async throws -> Result {
    guard !(await marker.isCompleted(studentID: studentID)) else {
      return Result(didRun: false, pointCount: 0)
    }

    let profile = try await onboarding.fetchProfile(studentId: studentID)
    let catalog = try await resolvedCatalog(studentID: studentID)
    let exerciseByID = Dictionary(
      catalog.exercises.map { ($0.id, $0) },
      uniquingKeysWith: { _, new in new }
    )
    let oldHistory = try await e1rm.fetchHistory(
      studentId: studentID,
      exerciseIds: Array(exerciseByID.keys)
    )
    let oldExerciseIDBySetLogID = Dictionary(
      oldHistory.values.flatMap { $0 }.map { ($0.setLogId, $0.exerciseId) },
      uniquingKeysWith: { _, new in new }
    )
    let setLogs = try await logs.fetchLogs(
      studentID: studentID,
      in: Date(timeIntervalSince1970: 0)...now()
    )
    let points = try await rebuild(
      studentID: studentID,
      context: ReplayContext(
        profile: profile,
        exerciseByID: exerciseByID,
        exerciseIDByPlanExerciseID: catalog.exerciseIDByPlanExerciseID,
        oldExerciseIDBySetLogID: oldExerciseIDBySetLogID
      ),
      setLogs: setLogs
    )
    try await e1rm.replaceHistory(studentId: studentID, with: points)
    await marker.markCompleted(studentID: studentID)
    return Result(didRun: true, pointCount: points.count)
  }

  private func rebuild(
    studentID: UUID,
    context: ReplayContext,
    setLogs: [StudentSetLog]
  ) async throws -> [E1RMHistoryPoint] {
    let rebuilt = InMemoryE1RMRepository()
    var includedExerciseIDs: Set<UUID> = []
    for log in setLogs.sorted(by: { $0.loggedAt < $1.loggedAt }) where log.completed {
      let exerciseID =
        context.oldExerciseIDBySetLogID[log.id]
        ?? context.exerciseIDByPlanExerciseID[log.planExerciseID]
      guard let exerciseID,
        let exercise = context.exerciseByID[exerciseID],
        let family = resolveCompetitionFamily(exercise: exercise, onboarding: context.profile)
      else { continue }

      includedExerciseIDs.insert(exerciseID)
      let recorder = E1RMRecorder(e1rm: rebuilt, now: { log.loggedAt })
      _ = await recorder.record(
        E1RMRecorder.Input(
          studentID: studentID,
          exerciseID: exerciseID,
          family: family,
          setLogID: log.id,
          weightKg: log.weightKg,
          reps: log.reps,
          rpe: log.rpe,
          completed: log.completed,
          failed: log.failed
        )
      )
    }

    let history = try await rebuilt.fetchHistory(
      studentId: studentID,
      exerciseIds: Array(includedExerciseIDs)
    )
    return history.values.flatMap { $0 }.sorted { $0.computedAt < $1.computedAt }
  }

  private func resolvedCatalog(studentID: UUID) async throws -> CatalogContext {
    var exercises = try await catalogReader?.fetchExerciseCatalog() ?? []
    let days = try await plans.fetchCycleDays(studentID: studentID)
    exercises.append(contentsOf: days.flatMap(\.exercises).map(\.exercise))
    return CatalogContext(
      exercises: exercises,
      exerciseIDByPlanExerciseID: Dictionary(
        days.flatMap(\.exercises).map { ($0.id, $0.exercise.id) },
        uniquingKeysWith: { _, new in new }
      )
    )
  }
}

actor InMemoryE1RMMigrationStore: E1RMMigrationStoring {
  private var completedStudents: Set<UUID> = []

  func isCompleted(studentID: UUID) -> Bool {
    completedStudents.contains(studentID)
  }

  func markCompleted(studentID: UUID) {
    completedStudents.insert(studentID)
  }
}
