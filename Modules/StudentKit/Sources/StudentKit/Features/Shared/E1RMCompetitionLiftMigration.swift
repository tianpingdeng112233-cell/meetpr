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
/// Canonical set logs are replayed chronologically through `E1RMRecorder` in
/// an isolated repository, then replace the student's local history in one
/// operation. Historical PR events are intentionally discarded: rebuilt
/// trusted points become the clean baseline for future PRs without replaying
/// celebration banners on app update.
actor E1RMCompetitionLiftMigration {
  private struct CatalogContext: Sendable {
    let exercises: [Exercise]
    let exerciseIDByPlanExerciseID: [UUID: UUID]
  }

  private struct ReplayContext: Sendable {
    let profile: OnboardingProfile?
    let exerciseByID: [UUID: Exercise]
    let exerciseIDByPlanExerciseID: [UUID: UUID]
    let priorConfidenceBySetLogID: [UUID: E1RMConfidence]
  }

  struct Result: Equatable, Sendable {
    let didRun: Bool
    let pointCount: Int
  }

  private let logs: any StudentTrainingLogRepository
  private let onboarding: any OnboardingProfileReading
  private let plans: any StudentPlanRepository
  private let catalogReader: (any ExerciseCatalogReading)?
  private let fallbackCatalog: [Exercise]
  private let e1rm: any E1RMRepository
  private let marker: any E1RMMigrationStoring
  private let now: @Sendable () -> Date

  init(
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    plans: any StudentPlanRepository,
    catalogReader: (any ExerciseCatalogReading)?,
    fallbackCatalog: [Exercise],
    e1rm: any E1RMRepository,
    marker: any E1RMMigrationStoring = UserDefaultsE1RMMigrationStore(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.logs = logs
    self.onboarding = onboarding
    self.plans = plans
    self.catalogReader = catalogReader
    self.fallbackCatalog = fallbackCatalog
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
    let history = try await e1rm.fetchHistory(
      studentId: studentID,
      exerciseIds: Array(exerciseByID.keys)
    )
    let priorConfidenceBySetLogID = Dictionary(
      history.values.flatMap { $0 }.map { ($0.setLogId, $0.confidence) },
      uniquingKeysWith: { _, new in new }
    )
    let setLogs = try await logs.fetchLogs(
      studentID: studentID,
      in: Date(timeIntervalSince1970: 0)...now(),
      scope: .all
    )

    let points = try await rebuild(
      studentID: studentID,
      context: ReplayContext(
        profile: profile,
        exerciseByID: exerciseByID,
        exerciseIDByPlanExerciseID: catalog.exerciseIDByPlanExerciseID,
        priorConfidenceBySetLogID: priorConfidenceBySetLogID
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
        log.exerciseID
        ?? log.planExerciseID.flatMap {
          context.exerciseIDByPlanExerciseID[$0]
        }
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
          failed: log.failed,
          origin: log.assumed ? .imported : .logged,
          priorConfidence: log.assumed ? context.priorConfidenceBySetLogID[log.id] : nil
        ))
    }

    let rebuiltHistory = try await rebuilt.fetchHistory(
      studentId: studentID,
      exerciseIds: Array(includedExerciseIDs)
    )
    return rebuiltHistory.values.flatMap { $0 }.sorted { $0.computedAt < $1.computedAt }
  }

  private func resolvedCatalog(studentID: UUID) async throws -> CatalogContext {
    var exercises = fallbackCatalog
    var exerciseIDByPlanExerciseID: [UUID: UUID] = [:]
    if let catalogReader {
      exercises.append(contentsOf: try await catalogReader.fetchExerciseCatalog())
    }
    if let plan = try? await plans.fetchCurrentPlan(studentID: studentID) {
      exercises.append(contentsOf: plan.days.flatMap(\.exercises).map(\.exercise))
      exerciseIDByPlanExerciseID = Dictionary(
        plan.days.flatMap(\.exercises).map { ($0.id, $0.exercise.id) },
        uniquingKeysWith: { _, new in new }
      )
    }
    return CatalogContext(
      exercises: exercises,
      exerciseIDByPlanExerciseID: exerciseIDByPlanExerciseID
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
