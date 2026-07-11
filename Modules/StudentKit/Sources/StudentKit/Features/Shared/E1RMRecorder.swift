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

    let point = makePoint(
      input: input,
      estimatedOneRepMaxKg: estimatedOneRepMaxKg,
      sourceWeightKg: weight,
      sourceRPE: rpe
    )

    do {
      // Read the baseline before insertion. Reapplying eligibility prevents
      // legacy low-RPE/high-rep points from permanently raising the PR bar.
      let previousMax = try await previousEligibleMax(for: input)
      try await e1rm.recordPoint(point)

      let baseline = previousMax ?? 0
      let noiseBand = E1RMPolicy.prNoiseBand(previousBestKg: baseline)
      guard estimatedOneRepMaxKg > baseline + noiseBand else { return nil }

      let event = PRBreakthroughEvent(
        id: UUID(),
        studentId: input.studentID,
        exerciseId: input.exerciseID,
        pointId: point.id,
        breakthroughE1RMKg: estimatedOneRepMaxKg,
        previousMaxE1RMKg: baseline,
        occurredAt: point.computedAt,
        acknowledgedAt: nil
      )
      try await e1rm.recordPR(event)
      return event
    } catch {
      return nil
    }
  }

  private func makePoint(
    input: Input,
    estimatedOneRepMaxKg: Double,
    sourceWeightKg: Double,
    sourceRPE: Double?
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
      sourceRPE: sourceRPE
    )
  }

  private func previousEligibleMax(for input: Input) async throws -> Double? {
    let history = try await e1rm.fetchHistory(
      studentId: input.studentID,
      exerciseId: input.exerciseID
    )
    return E1RMSeries.eligibleRaw(points: history, family: input.family)
      .map(\.e1RMKg)
      .max()
  }
}
