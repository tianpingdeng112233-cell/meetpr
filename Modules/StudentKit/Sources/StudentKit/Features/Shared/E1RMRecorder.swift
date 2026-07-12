import CoreModels
import Foundation
import RepositoryContracts

/// The one place a completed set becomes an e1RM point and possibly a PR
/// (spec 050 §3).
struct E1RMRecorder: Sendable {
  let e1rm: any E1RMRepository
  let now: @Sendable () -> Date

  struct Input: Sendable {
    let studentID: UUID
    let exerciseID: UUID
    let family: LiftFamily?
    let setLogID: UUID
    let weightKg: Decimal
    let reps: Int
    let rpe: Decimal?
    let completed: Bool
    let failed: Bool
    /// Migration/import paths may preserve an already-reviewed trust tier.
    /// Normal set recording leaves this nil and still runs the release anomaly gate.
    let priorConfidence: E1RMConfidence?

    init(
      studentID: UUID,
      exerciseID: UUID,
      family: LiftFamily?,
      setLogID: UUID,
      weightKg: Decimal,
      reps: Int,
      rpe: Decimal?,
      completed: Bool,
      failed: Bool,
      priorConfidence: E1RMConfidence? = nil
    ) {
      self.studentID = studentID
      self.exerciseID = exerciseID
      self.family = family
      self.setLogID = setLogID
      self.weightKg = weightKg
      self.reps = reps
      self.rpe = rpe
      self.completed = completed
      self.failed = failed
      self.priorConfidence = priorConfidence
    }
  }

  /// Eligible points are always recorded. A PR is emitted only when the new
  /// estimate clears both the prior eligible best and its configured noise
  /// band. Persistence remains best-effort and never blocks set logging.
  func record(_ input: Input) async -> PRBreakthroughEvent? {
    let weight = NSDecimalNumber(decimal: input.weightKg).doubleValue
    let rpe = input.rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
    guard
      E1RMEligibility.isEligible(
        completed: input.completed,
        failed: input.failed,
        reps: input.reps,
        rpe: rpe,
        family: input.family
      ),
      let estimatedOneRepMaxKg = E1RMCalculator.calculate(
        weightKg: weight,
        reps: input.reps,
        rpe: rpe
      )
    else {
      return nil
    }

    do {
      // Read the baseline before insertion. Reapplying eligibility and trust
      // filters prevents legacy-invalid or quarantined points raising the bar.
      let previousMax = try await previousTrustedMax(for: input)
      let verdict = E1RMPolicy.anomalyVerdict(
        newE1RMKg: estimatedOneRepMaxKg,
        previousBestKg: previousMax
      )
      let confidence = input.priorConfidence ?? (verdict == .normal ? .normal : .low)
      let point = makePoint(
        input: input,
        estimatedOneRepMaxKg: estimatedOneRepMaxKg,
        sourceWeightKg: weight,
        sourceRPE: rpe,
        confidence: confidence
      )
      try await e1rm.recordPoint(point)

      // Phase 1 persists both anomaly bands as `.low`; Phase 2 will confirm
      // hard suspects before they can become trusted.
      guard confidence == .normal else { return nil }
      return try await recordPRIfCleared(point: point, previousMax: previousMax)
    } catch {
      return nil
    }
  }

  private func makePoint(
    input: Input,
    estimatedOneRepMaxKg: Double,
    sourceWeightKg: Double,
    sourceRPE: Double?,
    confidence: E1RMConfidence
  ) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: UUID(),
      studentId: input.studentID,
      exerciseId: input.exerciseID,
      setLogId: input.setLogID,
      computedAt: now(),
      e1RMKg: estimatedOneRepMaxKg,
      sourceWeightKg: sourceWeightKg,
      sourceReps: input.reps,
      sourceRPE: sourceRPE,
      confidence: confidence
    )
  }

  private func previousTrustedMax(for input: Input) async throws -> Double? {
    let history = try await e1rm.fetchHistory(
      studentId: input.studentID,
      exerciseId: input.exerciseID
    )
    return E1RMSeries.trustedEligibleRaw(points: history, family: input.family)
      .map(\.e1RMKg)
      .max()
  }

  private func recordPRIfCleared(
    point: E1RMHistoryPoint,
    previousMax: Double?
  ) async throws -> PRBreakthroughEvent? {
    let baseline = previousMax ?? 0
    let noiseBand = E1RMPolicy.prNoiseBand(previousBestKg: baseline)
    guard point.e1RMKg > baseline + noiseBand else { return nil }

    let event = PRBreakthroughEvent(
      id: UUID(),
      studentId: point.studentId,
      exerciseId: point.exerciseId,
      pointId: point.id,
      breakthroughE1RMKg: point.e1RMKg,
      previousMaxE1RMKg: baseline,
      occurredAt: point.computedAt,
      acknowledgedAt: nil
    )
    try await e1rm.recordPR(event)
    return event
  }
}
