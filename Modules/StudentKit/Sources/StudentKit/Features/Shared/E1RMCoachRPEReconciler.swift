import CoreModels
import Foundation
import RepositoryContracts

actor E1RMCoachRPEReconciler {
  struct Result: Equatable, Sendable {
    let didReconcile: Bool
    let pointCount: Int
  }

  private struct CatalogContext: Sendable {
    let exerciseByID: [UUID: Exercise]
    let exerciseIDByPlanExerciseID: [UUID: UUID]
  }

  private let logs: any StudentTrainingLogRepository
  private let onboarding: any OnboardingProfileReading
  private let plans: any StudentPlanRepository
  private let catalogReader: (any ExerciseCatalogReading)?
  private let e1rm: any E1RMRepository
  private let now: @Sendable () -> Date
  private var inFlight: [UUID: Task<Result, any Error>] = [:]

  init(
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    plans: any StudentPlanRepository,
    catalogReader: (any ExerciseCatalogReading)?,
    e1rm: any E1RMRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.logs = logs
    self.onboarding = onboarding
    self.plans = plans
    self.catalogReader = catalogReader
    self.e1rm = e1rm
    self.now = now
  }

  func reconcile(studentID: UUID) async throws -> Result {
    if let inFlight = inFlight[studentID] {
      return try await inFlight.value
    }
    let task = Task { [self] in
      try await performReconciliation(studentID: studentID)
    }
    inFlight[studentID] = task
    do {
      let result = try await task.value
      inFlight[studentID] = nil
      return result
    } catch {
      inFlight[studentID] = nil
      throw error
    }
  }

  private func performReconciliation(studentID: UUID) async throws -> Result {
    async let profileTask = onboarding.fetchProfile(studentId: studentID)
    async let catalogTask = resolvedCatalog(studentID: studentID)
    async let setLogsTask = logs.fetchLogs(
      studentID: studentID,
      in: Date(timeIntervalSince1970: 0)...now()
    )
    let (profile, catalog, setLogs) = try await (profileTask, catalogTask, setLogsTask)
    let historySnapshot = try await e1rm.historySnapshot(
      studentId: studentID,
      exerciseIds: Array(catalog.exerciseByID.keys)
    )
    let oldPoints = historySnapshot.history.values.flatMap { $0 }
    let replayContext = Self.replayContext(
      profile: profile,
      catalog: catalog,
      oldPoints: oldPoints
    )
    guard
      needsReconciliation(
        setLogs: setLogs,
        context: replayContext
      )
    else {
      return Result(didReconcile: false, pointCount: 0)
    }

    let replayed = try await E1RMHistoryReplayService().rebuild(
      studentID: studentID,
      context: replayContext,
      setLogs: setLogs,
      confidencePolicy: .recompute
    )
    let didReplace = try await e1rm.replaceHistory(
      studentId: studentID,
      with: replayed.points,
      weightBaselines: replayed.weightBaselines,
      prEvents: try await existingPREvents(studentID: studentID),
      ifUnchangedSince: historySnapshot.revision
    )
    guard didReplace else {
      return Result(didReconcile: false, pointCount: 0)
    }
    return Result(didReconcile: true, pointCount: replayed.points.count)
  }

  private static func replayContext(
    profile: OnboardingProfile?,
    catalog: CatalogContext,
    oldPoints: [E1RMHistoryPoint]
  ) -> E1RMHistoryReplayContext {
    let oldPointBySetLogID = Dictionary(
      oldPoints.map { ($0.setLogId, $0) },
      uniquingKeysWith: { existing, candidate in
        existing.origin == .logged ? existing : candidate
      }
    )
    return E1RMHistoryReplayContext(
      profile: profile,
      exerciseByID: catalog.exerciseByID,
      exerciseIDByPlanExerciseID: catalog.exerciseIDByPlanExerciseID,
      oldExerciseIDBySetLogID: oldPointBySetLogID.mapValues(\.exerciseId),
      existingPointBySetLogID: oldPointBySetLogID,
      preservedPoints: oldPoints.filter { $0.origin == .imported }
    )
  }

  private func existingPREvents(studentID: UUID) async throws -> [PRBreakthroughEvent] {
    var events: [PRBreakthroughEvent] = []
    for family in LiftFamily.allCases {
      events.append(
        contentsOf: try await e1rm.fetchPRs(
          studentId: studentID,
          family: family
        ))
    }
    return events
  }

  private func needsReconciliation(
    setLogs: [StudentSetLog],
    context: E1RMHistoryReplayContext
  ) -> Bool {
    for log in setLogs where log.completed && !log.assumed {
      guard let existing = context.existingPointBySetLogID[log.id] else {
        if Self.shouldProducePoint(for: log, context: context) { return true }
        continue
      }
      guard existing.origin == .logged else { continue }
      let sourceCoachRPE = log.coachRPE.map { NSDecimalNumber(decimal: $0).doubleValue }
      if existing.sourceCoachRPE != sourceCoachRPE { return true }
    }
    return false
  }

  private static func shouldProducePoint(
    for log: StudentSetLog,
    context: E1RMHistoryReplayContext
  ) -> Bool {
    guard let exerciseID = context.exerciseID(for: log),
      let exercise = context.exerciseByID[exerciseID],
      let family = resolveCompetitionFamily(exercise: exercise, onboarding: context.profile)
    else { return false }
    let effectiveRPE = log.effectiveRPE.map { NSDecimalNumber(decimal: $0).doubleValue }
    guard
      E1RMEligibility.isEligible(
        completed: log.completed,
        failed: log.failed,
        reps: log.reps,
        rpe: effectiveRPE,
        family: family
      )
    else { return false }
    let weightKg = NSDecimalNumber(decimal: log.weightKg).doubleValue
    return E1RMCalculator.calculate(weightKg: weightKg, reps: log.reps, rpe: effectiveRPE) != nil
  }

  private func resolvedCatalog(studentID: UUID) async throws -> CatalogContext {
    var exercises = try await catalogReader?.fetchExerciseCatalog() ?? []
    let days = try await plans.fetchCycleDays(studentID: studentID)
    exercises.append(contentsOf: days.flatMap(\.exercises).map(\.exercise))
    return CatalogContext(
      exerciseByID: Dictionary(
        exercises.map { ($0.id, $0) },
        uniquingKeysWith: { _, new in new }
      ),
      exerciseIDByPlanExerciseID: Dictionary(
        days.flatMap(\.exercises).map { ($0.id, $0.exercise.id) },
        uniquingKeysWith: { _, new in new }
      )
    )
  }
}
