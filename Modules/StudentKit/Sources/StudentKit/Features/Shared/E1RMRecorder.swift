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
    let coachRPE: Decimal?
    let completed: Bool
    let failed: Bool
    /// Locked onboarding 1RM for the resolved competition family.
    let registeredOneRMKg: Decimal?
    /// Replay paths may preserve an already-reviewed trust tier or explicitly
    /// trust a newly eligible historical point. Live recording leaves this nil
    /// and still runs the release anomaly gate.
    let confidenceOverride: E1RMConfidence?

    init(
      studentID: UUID,
      exerciseID: UUID,
      family: LiftFamily?,
      setLogID: UUID,
      weightKg: Decimal,
      reps: Int,
      rpe: Decimal?,
      coachRPE: Decimal? = nil,
      completed: Bool,
      failed: Bool,
      registeredOneRMKg: Decimal? = nil,
      confidenceOverride: E1RMConfidence? = nil
    ) {
      self.studentID = studentID
      self.exerciseID = exerciseID
      self.family = family
      self.setLogID = setLogID
      self.weightKg = weightKg
      self.reps = reps
      self.rpe = rpe
      self.coachRPE = coachRPE
      self.completed = completed
      self.failed = failed
      self.registeredOneRMKg = registeredOneRMKg
      self.confidenceOverride = confidenceOverride
    }
  }

  private struct PointValues {
    let estimatedOneRepMaxKg: Double
    let sourceWeightKg: Double
    let sourceRPE: Double?
    let sourceCoachRPE: Double?
    let confidence: E1RMConfidence
  }

  private struct RecordingContext {
    let family: LiftFamily
    let weight: Double
    let sourceRPE: Double?
    let sourceCoachRPE: Double?
    let effectiveRPE: Double?
    let recordedAt: Date
    let baselines: Baselines

    var clearsMeasuredWeightBaseline: Bool {
      weight > baselines.measuredWeightKg
    }
  }

  /// Eligible points are always recorded. A PR is emitted only when the
  /// completed set's measured weight strictly clears both the registered 1RM
  /// and the persisted family-wide weight baseline. Every completed,
  /// non-failed competition set advances that baseline independently of point
  /// eligibility. Persistence remains best-effort and never blocks set logging.
  func record(_ input: Input) async -> PRBreakthroughEvent? {
    guard input.completed, !input.failed, let family = input.family else {
      return nil
    }

    let weight = NSDecimalNumber(decimal: input.weightKg).doubleValue
    let sourceRPE = input.rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
    let sourceCoachRPE = input.coachRPE.map { NSDecimalNumber(decimal: $0).doubleValue }
    let effectiveRPE = sourceCoachRPE ?? sourceRPE
    let recordedAt = now()

    do {
      let previousWeightBaseline = try await e1rm.recordWeightBaseline(
        E1RMWeightBaseline(
          studentId: input.studentID,
          family: family,
          maxWeightKg: weight,
          setLogId: input.setLogID,
          achievedAt: recordedAt
        )
      )
      let registeredOneRMKg =
        input.registeredOneRMKg
        .map { NSDecimalNumber(decimal: $0).doubleValue }
        .flatMap { $0 > 0 ? $0 : nil }
      let baselines = Baselines(
        e1RMKg: try await previousTrustedE1RMBaseline(for: input, family: family),
        measuredWeightKg: max(
          registeredOneRMKg ?? 0,
          previousWeightBaseline?.maxWeightKg ?? 0
        )
      )
      let context = RecordingContext(
        family: family,
        weight: weight,
        sourceRPE: sourceRPE,
        sourceCoachRPE: sourceCoachRPE,
        effectiveRPE: effectiveRPE,
        recordedAt: recordedAt,
        baselines: baselines
      )
      let storedPoint = await recordPointIfEligible(input, context: context)
      return try await recordPRIfCleared(
        input: input,
        point: storedPoint,
        context: context
      )
    } catch {
      return nil
    }
  }

  private func recordPointIfEligible(
    _ input: Input,
    context: RecordingContext
  ) async -> E1RMHistoryPoint? {
    guard
      E1RMEligibility.isEligible(
        completed: input.completed,
        failed: input.failed,
        reps: input.reps,
        rpe: context.effectiveRPE,
        family: context.family
      ),
      let estimatedOneRepMaxKg = E1RMCalculator.calculate(
        weightKg: context.weight,
        reps: input.reps,
        rpe: context.effectiveRPE
      )
    else {
      return nil
    }
    let confidence =
      input.confidenceOverride
      ?? E1RMPolicy.anomalyVerdict(
        newE1RMKg: estimatedOneRepMaxKg,
        previousBestKg: context.baselines.e1RMKg
      ).confidence
    let point = makePoint(
      input: input,
      family: context.family,
      recordedAt: context.recordedAt,
      values: PointValues(
        estimatedOneRepMaxKg: estimatedOneRepMaxKg,
        sourceWeightKg: context.weight,
        sourceRPE: context.sourceRPE,
        sourceCoachRPE: context.sourceCoachRPE,
        confidence: confidence
      )
    )
    return try? await e1rm.upsertPoint(point)
  }

  private func makePoint(
    input: Input,
    family: LiftFamily,
    recordedAt: Date,
    values: PointValues
  ) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: UUID(),
      studentId: input.studentID,
      exerciseId: input.exerciseID,
      family: family,
      setLogId: input.setLogID,
      computedAt: recordedAt,
      e1RMKg: values.estimatedOneRepMaxKg,
      sourceWeightKg: values.sourceWeightKg,
      sourceReps: input.reps,
      sourceRPE: values.sourceRPE,
      sourceCoachRPE: values.sourceCoachRPE,
      confidence: values.confidence,
      origin: .logged
    )
  }

  private struct Baselines {
    let e1RMKg: Double?
    let measuredWeightKg: Double
  }

  private func previousTrustedE1RMBaseline(
    for input: Input,
    family: LiftFamily
  ) async throws -> Double? {
    let history = try await e1rm.fetchHistory(studentId: input.studentID, family: family)
    let eligible = E1RMSeries.eligibleRaw(
      points: history.filter {
        !($0.setLogId == input.setLogID && $0.origin == .imported)
      },
      family: family
    )
    return eligible.filter { $0.confidence == .normal }.map(\.e1RMKg).max()
  }

  private func recordPRIfCleared(
    input: Input,
    point: E1RMHistoryPoint?,
    context: RecordingContext
  ) async throws -> PRBreakthroughEvent? {
    guard context.clearsMeasuredWeightBaseline else { return nil }

    let event = PRBreakthroughEvent(
      id: UUID(),
      studentId: input.studentID,
      exerciseId: input.exerciseID,
      family: context.family,
      pointId: point?.id,
      breakthroughE1RMKg: point?.e1RMKg,
      previousMaxE1RMKg: context.baselines.e1RMKg,
      breakthroughWeightKg: context.weight,
      previousMaxWeightKg: context.baselines.measuredWeightKg,
      occurredAt: context.recordedAt,
      acknowledgedAt: nil
    )
    try await e1rm.recordPR(event)
    return event
  }
}

extension E1RMAnomalyClassifier.Verdict {
  fileprivate var confidence: E1RMConfidence {
    self == .normal ? .normal : .low
  }
}

extension OnboardingProfile {
  func registeredOneRMKg(for family: LiftFamily?) -> Decimal? {
    switch family {
    case .squat: squat1RMKg
    case .bench: bench1RMKg
    case .deadlift: deadlift1RMKg
    case nil: nil
    }
  }
}
