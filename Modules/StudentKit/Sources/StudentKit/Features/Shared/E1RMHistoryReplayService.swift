import CoreModels
import Foundation
import RepositoryContracts

struct E1RMHistoryReplayContext: Sendable {
  let profile: OnboardingProfile?
  let exerciseByID: [UUID: Exercise]
  let exerciseIDByPlanExerciseID: [UUID: UUID]
  let oldExerciseIDBySetLogID: [UUID: UUID]
  let existingPointBySetLogID: [UUID: E1RMHistoryPoint]
  let preservedPoints: [E1RMHistoryPoint]

  func exerciseID(for log: StudentSetLog) -> UUID? {
    log.exerciseID
      ?? oldExerciseIDBySetLogID[log.id]
      ?? exerciseIDByPlanExerciseID[log.planExerciseID]
  }
}

struct E1RMHistoryReplayService: Sendable {
  enum ConfidencePolicy: Sendable {
    case preserveExistingOrNormal([UUID: E1RMConfidence])
    case recompute

    func override(for setLogID: UUID) -> E1RMConfidence? {
      switch self {
      case .preserveExistingOrNormal(let confidenceBySetLogID):
        confidenceBySetLogID[setLogID] ?? .normal
      case .recompute:
        nil
      }
    }
  }

  struct Result: Sendable {
    let points: [E1RMHistoryPoint]
    let weightBaselines: [E1RMWeightBaseline]
  }

  private enum ReplayEvent: Sendable {
    case preservedPoint(E1RMHistoryPoint)
    case setLog(StudentSetLog)

    var date: Date {
      switch self {
      case .preservedPoint(let point): point.computedAt
      case .setLog(let log): log.loggedAt
      }
    }

    var stableID: UUID {
      switch self {
      case .preservedPoint(let point): point.setLogId
      case .setLog(let log): log.id
      }
    }

    var order: Int {
      switch self {
      case .preservedPoint: 0
      case .setLog: 1
      }
    }
  }

  func rebuild(
    studentID: UUID,
    context: E1RMHistoryReplayContext,
    setLogs: [StudentSetLog],
    confidencePolicy: ConfidencePolicy
  ) async throws -> Result {
    let rebuilt = InMemoryE1RMRepository()
    var includedExerciseIDs: Set<UUID> = []
    let events = replayEvents(context: context, setLogs: setLogs)

    for event in events {
      switch event {
      case .preservedPoint(let point):
        includedExerciseIDs.insert(point.exerciseId)
        _ = try await rebuilt.upsertPoint(point)
      case .setLog(let log):
        guard let exerciseID = context.exerciseID(for: log),
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
            coachRPE: log.coachRPE,
            completed: log.completed,
            failed: log.failed,
            registeredOneRMKg: context.profile?.registeredOneRMKg(for: family),
            confidenceOverride: confidencePolicy.override(for: log.id)
          )
        )
      }
    }

    let history = try await rebuilt.fetchHistory(
      studentId: studentID,
      exerciseIds: Array(includedExerciseIDs)
    )
    let stablePoints = history.values.flatMap { $0 }.map { point in
      guard let existingID = context.existingPointBySetLogID[point.setLogId]?.id else {
        return point
      }
      return point.replacing(id: existingID)
    }
    return Result(
      points: stablePoints.sorted(by: Self.pointsPrecede),
      weightBaselines: try await rebuilt.fetchWeightBaselines(studentId: studentID)
    )
  }

  private func replayEvents(
    context: E1RMHistoryReplayContext,
    setLogs: [StudentSetLog]
  ) -> [ReplayEvent] {
    let preserved = context.preservedPoints.map(ReplayEvent.preservedPoint)
    let canonical =
      setLogs
      .filter { $0.completed && !$0.assumed }
      .map(ReplayEvent.setLog)
    return (preserved + canonical).sorted { lhs, rhs in
      if lhs.date != rhs.date { return lhs.date < rhs.date }
      if lhs.stableID != rhs.stableID {
        return lhs.stableID.uuidString < rhs.stableID.uuidString
      }
      return lhs.order < rhs.order
    }
  }

  private static func pointsPrecede(
    _ lhs: E1RMHistoryPoint,
    _ rhs: E1RMHistoryPoint
  ) -> Bool {
    if lhs.computedAt != rhs.computedAt { return lhs.computedAt < rhs.computedAt }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}
