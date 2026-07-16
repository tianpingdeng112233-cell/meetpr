// swiftlint:disable file_length
import CoreModels
import Foundation
import RepositoryContracts

/// Imports assumed-complete plan history into the local e1RM timeline. It is
/// intentionally separate from `E1RMRecorder`: this batch path must never
/// create PR events, celebration banners, or training telemetry (spec 053).
actor ImportedHistoryBackfill {
  /// Plan-web imports at most 12 weeks (84 days); the extra margin keeps the
  /// complete imported batch inside the bounded fetch window.
  static let backfillWindowDays = 120
  private static let fetchSliceDays = 28

  struct Result: Sendable {
    let pendingReviews: [PendingImportedHistoryReview]
    /// Points inserted for a set-log identity that had no imported point yet.
    /// Idempotent replays report zero so callers skip needless reloads.
    let newImportedPointCount: Int
  }

  fileprivate struct Candidate: Sendable {
    let log: StudentSetLog
    let exerciseID: UUID
    let family: LiftFamily?
    let e1RMKg: Double
    let sourceWeightKg: Double
    let sourceRPE: Double?
  }

  private struct ExerciseContext: Sendable {
    let exerciseByID: [UUID: Exercise]
    let exerciseIDByPlanExerciseID: [UUID: UUID]
  }

  private struct ReviewPlan: Sendable {
    let confidenceBySetLogID: [UUID: E1RMConfidence]
    let pendingPlans: [LiftFamily: PendingPlan]
    let pendingSetLogIDs: [LiftFamily: Set<UUID>]
  }

  private let logs: any StudentTrainingLogRepository
  private let onboarding: any OnboardingProfileReading
  private let plans: any StudentPlanRepository
  private let catalogReader: (any ExerciseCatalogReading)?
  private let e1rm: any E1RMRepository
  private let reviews: any ImportedHistoryReviewStoring
  private let now: @Sendable () -> Date
  private var calendar: Calendar
  private var inFlightBackfills: [UUID: Task<Result, any Error>] = [:]
  private var exclusiveTails: [UUID: Task<Void, Never>] = [:]

  init(
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    plans: any StudentPlanRepository,
    catalogReader: (any ExerciseCatalogReading)?,
    e1rm: any E1RMRepository,
    reviews: any ImportedHistoryReviewStoring = LocalImportedHistoryReviewStore(),
    now: @escaping @Sendable () -> Date = { Date() },
    calendar: Calendar = Calendar(identifier: .gregorian)
  ) {
    self.logs = logs
    self.onboarding = onboarding
    self.plans = plans
    self.catalogReader = catalogReader
    self.e1rm = e1rm
    self.reviews = reviews
    self.now = now
    self.calendar = calendar
  }

  /// Serializes concurrent triggers (root task, tab switch, pull-to-refresh):
  /// overlapping calls join the in-flight run instead of racing pending-review
  /// creation, which would mint duplicate review IDs and orphan the first
  /// alert's answer (spec 053 §5 one-shot semantics).
  func backfill(studentID: UUID) async throws -> Result {
    if let inFlight = inFlightBackfills[studentID] {
      return try await inFlight.value
    }
    let task = Task { [self] in
      try await runExclusively(studentID: studentID) {
        try await self.performBackfill(studentID: studentID)
      }
    }
    inFlightBackfills[studentID] = task
    do {
      let result = try await task.value
      inFlightBackfills[studentID] = nil
      return result
    } catch {
      inFlightBackfills[studentID] = nil
      throw error
    }
  }

  /// Chains one student's backfill and answer operations onto a single serial
  /// tail. The actor is reentrant across repository awaits, so without this an
  /// answer landing mid-backfill would be overwritten by the run's stale
  /// pending/confidence snapshot (resurrecting the review it just resolved).
  private func runExclusively<T: Sendable>(
    studentID: UUID,
    _ operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    let previousTail = exclusiveTails[studentID]
    let work = Task<T, any Error> {
      await previousTail?.value
      return try await operation()
    }
    exclusiveTails[studentID] = Task { _ = try? await work.value }
    return try await work.value
  }

  /// Fetches the complete bounded window in API-range slices. Repeating this
  /// operation is safe because repository writes are upserts by set-log ID.
  private func performBackfill(studentID: UUID) async throws -> Result {
    let profile = try await onboarding.fetchProfile(studentId: studentID)
    let baselines = Self.baselines(from: profile)
    let exerciseContext = try await resolvedExercises(studentID: studentID)
    let candidates = try await eligibleCandidates(
      studentID: studentID,
      exerciseContext: exerciseContext
    )
    let existingBySetLogID = try await existingImportedPoints(
      studentID: studentID,
      exerciseIDs: Set(candidates.map(\.exerciseID))
    )
    let reviewPlan = try await makeReviewPlan(
      studentID: studentID,
      candidates: candidates,
      baselines: baselines,
      existingBySetLogID: existingBySetLogID
    )
    let pointIDsByFamily = try await upsert(
      candidates: candidates,
      studentID: studentID,
      existingBySetLogID: existingBySetLogID,
      reviewPlan: reviewPlan
    )
    let pendingReviews = try await savePendingReviews(
      studentID: studentID,
      pendingPlans: reviewPlan.pendingPlans,
      pointIDsByFamily: pointIDsByFamily
    )
    return Result(
      pendingReviews: pendingReviews.sorted { $0.family.rawValue < $1.family.rawValue },
      newImportedPointCount: candidates.count { existingBySetLogID[$0.log.id] == nil }
    )
  }

  /// Applies an answer only to the IDs captured by the current pending review.
  /// A later higher batch creates a fresh pending review, so this cannot
  /// rewrite an older rejected batch (spec 053 §5).
  func answer(
    _ review: PendingImportedHistoryReview,
    decision: ImportedHistoryReviewDecision
  ) async throws {
    try await runExclusively(studentID: review.studentID) {
      try await self.performAnswer(review, decision: decision)
    }
  }

  private func performAnswer(
    _ review: PendingImportedHistoryReview,
    decision: ImportedHistoryReviewDecision
  ) async throws {
    guard
      let pending = try await reviews.pendingReview(
        studentID: review.studentID,
        family: review.family
      ),
      pending.id == review.id
    else { return }

    try await e1rm.updatePointConfidence(
      studentId: pending.studentID,
      pointIDs: pending.pointIDs,
      confidence: decision.confidence
    )
    try await reviews.save(
      review: ImportedHistoryReviewRecord(
        studentID: pending.studentID,
        family: pending.family,
        decision: decision,
        reviewedMaxE1RM: pending.reviewedMaxE1RM
      )
    )
    try await reviews.removePendingReview(studentID: pending.studentID, family: pending.family)
  }

  private func makeReviewPlan(
    studentID: UUID,
    candidates: [Candidate],
    baselines: [LiftFamily: Double],
    existingBySetLogID: [UUID: E1RMHistoryPoint]
  ) async throws -> ReviewPlan {
    let grouped = Self.groupCandidatesAboveBaseline(candidates, baselines: baselines)
    var confidenceBySetLogID: [UUID: E1RMConfidence] = [:]
    var pendingPlans: [LiftFamily: PendingPlan] = [:]
    var pendingSetLogIDs: [LiftFamily: Set<UUID>] = [:]

    for (family, familyCandidates) in grouped {
      guard let maximum = familyCandidates.max(by: { $0.e1RMKg < $1.e1RMKg }),
        let baseline = baselines[family]
      else { continue }
      let newCandidates = familyCandidates.filter { existingBySetLogID[$0.log.id] == nil }

      if let pending = try await reviews.pendingReview(studentID: studentID, family: family) {
        Self.assign(.low, to: newCandidates, confidenceBySetLogID: &confidenceBySetLogID)
        pendingSetLogIDs[family] = Set(newCandidates.map(\.log.id))
        pendingPlans[family] = PendingPlan(
          family: family,
          existing: pending,
          maximum: maximum,
          baseline: baseline
        )
        continue
      }

      guard let newMaximum = newCandidates.max(by: { $0.e1RMKg < $1.e1RMKg }) else { continue }
      if let review = try await reviews.review(studentID: studentID, family: family),
        newMaximum.e1RMKg <= review.reviewedMaxE1RM
      {
        Self.assign(
          review.decision.confidence,
          to: newCandidates,
          confidenceBySetLogID: &confidenceBySetLogID
        )
        continue
      }

      Self.assign(.low, to: newCandidates, confidenceBySetLogID: &confidenceBySetLogID)
      pendingSetLogIDs[family] = Set(newCandidates.map(\.log.id))
      pendingPlans[family] = PendingPlan(
        family: family,
        existing: nil,
        maximum: newMaximum,
        baseline: baseline
      )
    }

    return ReviewPlan(
      confidenceBySetLogID: confidenceBySetLogID,
      pendingPlans: pendingPlans,
      pendingSetLogIDs: pendingSetLogIDs
    )
  }

  private func upsert(
    candidates: [Candidate],
    studentID: UUID,
    existingBySetLogID: [UUID: E1RMHistoryPoint],
    reviewPlan: ReviewPlan
  ) async throws -> [LiftFamily: Set<UUID>] {
    var pointIDsByFamily: [LiftFamily: Set<UUID>] = [:]
    for candidate in candidates {
      let confidence =
        reviewPlan.confidenceBySetLogID[candidate.log.id]
        ?? existingBySetLogID[candidate.log.id]?.confidence
        ?? .normal
      let stored = try await e1rm.upsertPoint(
        makePoint(from: candidate, studentID: studentID, confidence: confidence)
      )
      if let family = candidate.family,
        reviewPlan.pendingSetLogIDs[family]?.contains(candidate.log.id) == true
      {
        pointIDsByFamily[family, default: []].insert(stored.id)
      }
    }
    return pointIDsByFamily
  }

  private func savePendingReviews(
    studentID: UUID,
    pendingPlans: [LiftFamily: PendingPlan],
    pointIDsByFamily: [LiftFamily: Set<UUID>]
  ) async throws -> [PendingImportedHistoryReview] {
    var pendingReviews: [PendingImportedHistoryReview] = []
    for (family, plan) in pendingPlans {
      let review = plan.makeReview(
        studentID: studentID,
        pointIDs: pointIDsByFamily[family, default: []]
      )
      try await reviews.save(pendingReview: review)
      pendingReviews.append(review)
    }
    return pendingReviews
  }
}

extension ImportedHistoryBackfill {
  private func eligibleCandidates(
    studentID: UUID,
    exerciseContext: ExerciseContext
  ) async throws -> [Candidate] {
    let allLogs = try await fetchWindow(studentID: studentID)
    return allLogs.compactMap { log in
      guard log.assumed, log.completed, !log.failed,
        let exerciseID =
          log.exerciseID ?? exerciseContext.exerciseIDByPlanExerciseID[log.planExerciseID]
      else { return nil }

      let family = exerciseContext.exerciseByID[exerciseID]?.mainLiftFamily
      let sourceWeightKg = NSDecimalNumber(decimal: log.weightKg).doubleValue
      let sourceRPE = log.rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
      guard E1RMEligibility.isEligible(reps: log.reps, rpe: sourceRPE, family: family),
        let e1RMKg = E1RMCalculator.calculate(
          weightKg: sourceWeightKg,
          reps: log.reps,
          rpe: sourceRPE
        )
      else { return nil }

      return Candidate(
        log: log,
        exerciseID: exerciseID,
        family: family,
        e1RMKg: e1RMKg,
        sourceWeightKg: sourceWeightKg,
        sourceRPE: sourceRPE
      )
    }
  }

  private func fetchWindow(studentID: UUID) async throws -> [StudentSetLog] {
    let end = now()
    guard let start = calendar.date(byAdding: .day, value: -Self.backfillWindowDays, to: end) else {
      return []
    }

    var lowerBound = start
    var allLogs: [UUID: StudentSetLog] = [:]
    while lowerBound < end {
      let sliceEnd = min(
        calendar.date(byAdding: .day, value: Self.fetchSliceDays, to: lowerBound) ?? end,
        end
      )
      let slice = try await logs.fetchLogs(
        studentID: studentID,
        in: lowerBound...sliceEnd
      )
      for log in slice {
        allLogs[log.id] = log
      }
      lowerBound = sliceEnd
    }

    return allLogs.values.sorted {
      if $0.loggedAt == $1.loggedAt {
        return $0.id.uuidString < $1.id.uuidString
      }
      return $0.loggedAt < $1.loggedAt
    }
  }

  private func resolvedExercises(studentID: UUID) async throws -> ExerciseContext {
    var exercises = try await catalogReader?.fetchExerciseCatalog() ?? []
    let days = try await plans.fetchCycleDays(studentID: studentID)
    exercises.append(contentsOf: days.flatMap(\.exercises).map(\.exercise))
    return ExerciseContext(
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

  private func existingImportedPoints(
    studentID: UUID,
    exerciseIDs: Set<UUID>
  ) async throws -> [UUID: E1RMHistoryPoint] {
    guard !exerciseIDs.isEmpty else { return [:] }
    let histories = try await e1rm.fetchHistory(
      studentId: studentID,
      exerciseIds: Array(exerciseIDs)
    )
    return Dictionary(
      histories.values
        .flatMap { $0 }
        .filter { $0.origin == .imported }
        .map { ($0.setLogId, $0) },
      uniquingKeysWith: { existing, _ in existing }
    )
  }

  private func makePoint(
    from candidate: Candidate,
    studentID: UUID,
    confidence: E1RMConfidence
  ) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: UUID(),
      studentId: studentID,
      exerciseId: candidate.exerciseID,
      setLogId: candidate.log.id,
      computedAt: candidate.log.loggedAt,
      e1RMKg: candidate.e1RMKg,
      sourceWeightKg: candidate.sourceWeightKg,
      sourceReps: candidate.log.reps,
      sourceRPE: candidate.sourceRPE,
      confidence: confidence,
      origin: .imported
    )
  }

  private static func baselines(from profile: OnboardingProfile?) -> [LiftFamily: Double] {
    guard let profile else { return [:] }
    return [
      .squat: profile.squat1RMKg,
      .bench: profile.bench1RMKg,
      .deadlift: profile.deadlift1RMKg,
    ].compactMapValues { $0.map { NSDecimalNumber(decimal: $0).doubleValue } }
  }

  private static func groupCandidatesAboveBaseline(
    _ candidates: [Candidate],
    baselines: [LiftFamily: Double]
  ) -> [LiftFamily: [Candidate]] {
    var grouped: [LiftFamily: [Candidate]] = [:]
    for candidate in candidates {
      guard let family = candidate.family,
        let baseline = baselines[family],
        candidate.e1RMKg > baseline
      else { continue }
      grouped[family, default: []].append(candidate)
    }
    return grouped
  }

  private static func assign(
    _ confidence: E1RMConfidence,
    to candidates: [Candidate],
    confidenceBySetLogID: inout [UUID: E1RMConfidence]
  ) {
    for candidate in candidates {
      confidenceBySetLogID[candidate.log.id] = confidence
    }
  }
}

private struct PendingPlan: Sendable {
  let family: LiftFamily
  let existing: PendingImportedHistoryReview?
  let maximum: ImportedHistoryBackfill.Candidate
  let baseline: Double

  func makeReview(studentID: UUID, pointIDs: Set<UUID>) -> PendingImportedHistoryReview {
    let mergedIDs = existing?.pointIDs.union(pointIDs) ?? pointIDs
    let useNewMaximum = maximum.e1RMKg > (existing?.reviewedMaxE1RM ?? -.infinity)
    return PendingImportedHistoryReview(
      id: existing?.id ?? UUID(),
      studentID: studentID,
      family: family,
      pointIDs: mergedIDs,
      reviewedMaxE1RM: useNewMaximum
        ? maximum.e1RMKg : existing?.reviewedMaxE1RM ?? maximum.e1RMKg,
      baseline1RMKg: baseline,
      sourceWeightKg: useNewMaximum
        ? maximum.sourceWeightKg : existing?.sourceWeightKg ?? maximum.sourceWeightKg,
      sourceReps: useNewMaximum ? maximum.log.reps : existing?.sourceReps ?? maximum.log.reps,
      sourceE1RMKg: useNewMaximum
        ? maximum.e1RMKg : existing?.sourceE1RMKg ?? maximum.e1RMKg
    )
  }
}
