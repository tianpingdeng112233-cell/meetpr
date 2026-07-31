import CoreModels
import Foundation
import RepositoryContracts

protocol E1RMMigrationStoring: Sendable {
  func isCompleted(studentID: UUID) async -> Bool
  func markCompleted(studentID: UUID) async
}

actor UserDefaultsE1RMMigrationStore: E1RMMigrationStoring {
  private static let version = "coach-rpe-low-rpe-replay-v2"
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
actor E1RMCompetitionLiftMigration: E1RMCompetitionLiftRunning {
  private struct CatalogContext: Sendable {
    let exercises: [Exercise]
    let exerciseIDByPlanExerciseID: [UUID: UUID]
  }

  private struct ReplayPreparation: Sendable {
    let context: E1RMHistoryReplayContext
    let confidenceBySetLogID: [UUID: E1RMConfidence]
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
    let replay = Self.replayPreparation(
      profile: profile,
      exerciseByID: exerciseByID,
      exerciseIDByPlanExerciseID: catalog.exerciseIDByPlanExerciseID,
      oldHistory: oldHistory
    )
    let setLogs = try await logs.fetchLogs(
      studentID: studentID,
      in: Date(timeIntervalSince1970: 0)...now()
    )
    let rebuilt = try await E1RMHistoryReplayService().rebuild(
      studentID: studentID,
      context: replay.context,
      setLogs: setLogs,
      confidencePolicy: .preserveExistingOrNormal(replay.confidenceBySetLogID)
    )
    try await e1rm.replaceHistory(
      studentId: studentID,
      with: rebuilt.points,
      weightBaselines: rebuilt.weightBaselines,
      prEvents: []
    )
    await marker.markCompleted(studentID: studentID)
    return Result(didRun: true, pointCount: rebuilt.points.count)
  }

  private static func replayPreparation(
    profile: OnboardingProfile?,
    exerciseByID: [UUID: Exercise],
    exerciseIDByPlanExerciseID: [UUID: UUID],
    oldHistory: [UUID: [E1RMHistoryPoint]]
  ) -> ReplayPreparation {
    let oldPoints = oldHistory.values.flatMap { $0 }
    let oldPointBySetLogID = Dictionary(
      oldPoints.map { ($0.setLogId, $0) },
      uniquingKeysWith: { existing, _ in existing }
    )
    return ReplayPreparation(
      context: E1RMHistoryReplayContext(
        profile: profile,
        exerciseByID: exerciseByID,
        exerciseIDByPlanExerciseID: exerciseIDByPlanExerciseID,
        oldExerciseIDBySetLogID: oldPointBySetLogID.mapValues(\.exerciseId),
        existingPointBySetLogID: oldPointBySetLogID,
        preservedPoints: []
      ),
      confidenceBySetLogID: oldPointBySetLogID.mapValues(\.confidence)
    )
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
