import CoreModels
import Foundation
import RepositoryContracts

/// The one place a completed set becomes an e1RM point and (maybe) a PR —
/// TodayWorkout and SoloSession both delegate here (spec 050 §3; replaces
/// their duplicated recordE1RMPoint copies).
struct E1RMRecorder: Sendable {
  let e1rm: any E1RMRepository
  let now: @Sendable () -> Date

  /// Records the point when the set is eligible (spec 050 §1) and returns a
  /// PR event when the estimate clears the noise band over the prior best:
  /// max(0.5 kg, best × 3%) — a same-condition wobble is not a record.
  /// e1RM persistence stays best-effort: failures return nil and never block
  /// set logging; a banner only celebrates durably recorded history.
  func record(
    studentID: UUID,
    exerciseID: UUID,
    family: LiftFamily?,
    setLogID: UUID,
    weightKg: Decimal,
    reps: Int,
    rpe: Decimal?,
    failed: Bool
  ) async -> PRBreakthroughEvent? {
    guard !failed else { return nil }
    let weight = NSDecimalNumber(decimal: weightKg).doubleValue
    let rpeValue = rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
    guard E1RMEligibility.isEligible(reps: reps, rpe: rpeValue, family: family) else {
      return nil
    }
    guard
      let estimatedOneRepMaxKg = E1RMCalculator.calculate(
        weightKg: weight, reps: reps, rpe: rpeValue)
    else { return nil }

    let point = E1RMHistoryPoint(
      id: UUID(),
      studentId: studentID,
      exerciseId: exerciseID,
      setLogId: setLogID,
      computedAt: now(),
      e1RMKg: estimatedOneRepMaxKg,
      sourceWeightKg: weight,
      sourceReps: reps,
      sourceRPE: rpeValue
    )
    do {
      // Baseline BEFORE inserting the new point, over the full history
      // (.distantFuture): a strictly-earlier filter at point.computedAt would
      // miss a same-timestamp sibling and double-fire PRs (Codex review P1).
      let previousMax = try await e1rm.maxBefore(
        studentId: studentID, exerciseId: exerciseID, before: .distantFuture)
      try await e1rm.recordPoint(point)

      let band = max(0.5, (previousMax ?? 0) * 0.03)
      if estimatedOneRepMaxKg > (previousMax ?? 0) + band {
        let event = PRBreakthroughEvent(
          id: UUID(),
          studentId: studentID,
          exerciseId: exerciseID,
          pointId: point.id,
          breakthroughE1RMKg: estimatedOneRepMaxKg,
          previousMaxE1RMKg: previousMax ?? 0,
          occurredAt: point.computedAt,
          acknowledgedAt: nil
        )
        try await e1rm.recordPR(event)
        return event
      }
    } catch {
      return nil
    }
    return nil
  }
}
