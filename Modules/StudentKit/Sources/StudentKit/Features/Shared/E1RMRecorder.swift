import CoreModels
import Foundation
import RepositoryContracts

/// The one place a completed set becomes an e1RM point and (maybe) a PR —
/// TodayWorkout and SoloSession both delegate here (spec 050 §3; replaces
/// their duplicated recordE1RMPoint copies).
struct E1RMRecorder: Sendable {
  let e1rm: any E1RMRepository
  let now: @Sendable () -> Date

  /// One completed set, exactly what the recorder needs to judge it.
  struct Input: Sendable {
    let studentID: UUID
    let exerciseID: UUID
    let family: LiftFamily?
    let setLogID: UUID
    let weightKg: Decimal
    let reps: Int
    let rpe: Decimal?
    let failed: Bool
    let origin: E1RMPointOrigin
    let priorConfidence: E1RMConfidence?

    init(
      studentID: UUID,
      exerciseID: UUID,
      family: LiftFamily?,
      setLogID: UUID,
      weightKg: Decimal,
      reps: Int,
      rpe: Decimal?,
      failed: Bool,
      origin: E1RMPointOrigin = .logged,
      priorConfidence: E1RMConfidence? = nil
    ) {
      self.studentID = studentID
      self.exerciseID = exerciseID
      self.family = family
      self.setLogID = setLogID
      self.weightKg = weightKg
      self.reps = reps
      self.rpe = rpe
      self.failed = failed
      self.origin = origin
      self.priorConfidence = priorConfidence
    }
  }

  /// Records the point when the set is eligible (spec 050 §1) and returns a
  /// PR event when the estimate clears the noise band over the prior best:
  /// max(0.5 kg, best × 3%) — a same-condition wobble is not a record.
  /// e1RM persistence stays best-effort: failures return nil and never block
  /// set logging; a banner only celebrates durably recorded history.
  func record(_ input: Input) async -> PRBreakthroughEvent? {
    let studentID = input.studentID
    let exerciseID = input.exerciseID
    guard !input.failed else { return nil }
    let weight = NSDecimalNumber(decimal: input.weightKg).doubleValue
    let rpeValue = input.rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
    guard E1RMEligibility.isEligible(reps: input.reps, rpe: rpeValue, family: input.family)
    else {
      return nil
    }
    guard
      let estimatedOneRepMaxKg = E1RMCalculator.calculate(
        weightKg: weight, reps: input.reps, rpe: rpeValue)
    else { return nil }

    do {
      // Baseline over prior *trusted* points (maxBefore filters `.normal`): a
      // quarantined spike must not become the bar the next PR has to clear.
      // Full history (.distantFuture) — a strictly-earlier filter at
      // point.computedAt would miss a same-timestamp sibling and double-fire
      // PRs (Codex review P1). The same set-log identity is excluded so a
      // stale assumed value never gates its own real-log replacement
      // (spec 053 §3).
      let previousNormalMax = try await e1rm.maxBefore(
        studentId: studentID, exerciseId: exerciseID, before: .distantFuture,
        excludingSetLogId: input.setLogID)

      // Graded anomaly guard (spec 050 §5): a single mis-logged set (175→275
      // fat-finger) is quarantined as `.low` — kept for honest scatter, kept
      // out of current/best/PR. Phase 2 will interrupt to confirm suspect
      // entries; Phase 1 stores them silently.
      let verdict = E1RMAnomalyClassifier.classify(
        newE1RMKg: estimatedOneRepMaxKg, priorNormalBestKg: previousNormalMax)
      let confidence: E1RMConfidence =
        verdict == .normal ? input.priorConfidence ?? .normal : .low
      let point = E1RMHistoryPoint(
        id: UUID(),
        studentId: studentID,
        exerciseId: exerciseID,
        setLogId: input.setLogID,
        computedAt: now(),
        e1RMKg: estimatedOneRepMaxKg,
        sourceWeightKg: weight,
        sourceReps: input.reps,
        sourceRPE: rpeValue,
        confidence: confidence,
        origin: input.origin
      )
      let storedPoint = try await e1rm.upsertPoint(point)

      // Only a trusted point that clears the noise band is a PR.
      guard confidence == .normal else { return nil }
      return try await recordPRIfCleared(point: storedPoint, previousNormalMax: previousNormalMax)
    } catch {
      return nil
    }
  }

  /// Fires a PR event when the point clears the noise band over the prior
  /// trusted best: max(0.5 kg, best × 3%) — a same-condition wobble is not
  /// a record.
  private func recordPRIfCleared(
    point: E1RMHistoryPoint, previousNormalMax: Double?
  ) async throws -> PRBreakthroughEvent? {
    let band = max(0.5, (previousNormalMax ?? 0) * 0.03)
    guard point.e1RMKg > (previousNormalMax ?? 0) + band else { return nil }
    let event = PRBreakthroughEvent(
      id: UUID(),
      studentId: point.studentId,
      exerciseId: point.exerciseId,
      pointId: point.id,
      breakthroughE1RMKg: point.e1RMKg,
      previousMaxE1RMKg: previousNormalMax ?? 0,
      occurredAt: point.computedAt,
      acknowledgedAt: nil
    )
    try await e1rm.recordPR(event)
    return event
  }
}
