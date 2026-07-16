// swiftlint:disable file_length
import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private let backfillStudentID = UUID()
private let backfillNow = Date(timeIntervalSince1970: 1_783_468_800)

@Test func backfillFiltersEligibilityUsesLoggedAtAndIsIdempotentWithoutPRs() async throws {
  let squat = backfillSlot(family: .squat)
  let deadlift = backfillSlot(family: .deadlift)
  let eligible = backfillLog(slot: squat, weightKg: 140, reps: 5, rpe: nil, daysAgo: 80)
  let lowRPE = backfillLog(slot: squat, weightKg: 140, reps: 5, rpe: 6, daysAgo: 70)
  let highRep = backfillLog(slot: squat, weightKg: 100, reps: 11, rpe: 8, daysAgo: 60)
  let deadliftSix = backfillLog(
    slot: deadlift,
    weightKg: 160,
    reps: 6,
    rpe: 8,
    daysAgo: 50
  )
  let unresolved = backfillLog(
    planExerciseID: UUID(),
    weightKg: 140,
    reps: 5,
    rpe: 8,
    daysAgo: 40
  )
  let actual = backfillLog(
    slot: squat, weightKg: 140, daysAgo: 30, assumed: false)
  let incomplete = backfillLog(
    slot: squat, weightKg: 140, daysAgo: 20, completed: false)
  let failed = backfillLog(
    slot: squat, weightKg: 140, daysAgo: 10, failed: true)
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(
    logs: [
      eligible, lowRPE, highRep, deadliftSix, unresolved, actual, incomplete, failed,
    ],
    slots: [squat, deadlift],
    e1rm: e1rm
  )

  let first = try await service.backfill(studentID: backfillStudentID)
  let second = try await service.backfill(studentID: backfillStudentID)
  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )

  #expect(first.newImportedPointCount == 1)
  #expect(second.newImportedPointCount == 0)
  #expect(history.count == 1)
  #expect(history.first?.origin == .imported)
  #expect(history.first?.computedAt == eligible.loggedAt)
  #expect(try await e1rm.unacknowledgedPRs(studentId: backfillStudentID).isEmpty)
}

@Test func logExerciseIDImportsWhenCurrentCycleIsEmpty() async throws {
  let exerciseID = UUID()
  let log = backfillLog(
    planExerciseID: UUID(),
    exerciseID: exerciseID,
    weightKg: 140,
    daysAgo: 40
  )
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(logs: [log], slots: [], planSlots: [], e1rm: e1rm)

  let result = try await service.backfill(studentID: backfillStudentID)
  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: exerciseID
  )

  #expect(result.newImportedPointCount == 1)
  #expect(history.count == 1)
  #expect(history.first?.setLogId == log.id)
  #expect(result.pendingReviews.isEmpty)
}

@Test func missingLogExerciseIDFallsBackToCurrentCycleMapping() async throws {
  let squat = backfillSlot(family: .squat)
  let log = backfillLog(slot: squat, weightKg: 100, daysAgo: 40)
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(logs: [log], slots: [squat], e1rm: e1rm)

  let result = try await service.backfill(studentID: backfillStudentID)
  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )

  #expect(log.exerciseID == nil)
  #expect(result.newImportedPointCount == 1)
  #expect(history.first?.setLogId == log.id)
}

@Test func unresolvedLogWithoutExerciseIDIsSkipped() async throws {
  let unresolvedExerciseID = UUID()
  let log = backfillLog(
    planExerciseID: unresolvedExerciseID,
    weightKg: 140,
    daysAgo: 40
  )
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(logs: [log], slots: [], planSlots: [], e1rm: e1rm)

  let result = try await service.backfill(studentID: backfillStudentID)

  #expect(result.newImportedPointCount == 0)
  #expect(
    try await e1rm.fetchHistory(
      studentId: backfillStudentID,
      exerciseId: unresolvedExerciseID
    ).isEmpty
  )
}

@Test func confirmedReviewPromotesBatchAndReplayDoesNotReprompt() async throws {
  let squat = backfillSlot(family: .squat)
  let belowBaseline = backfillLog(slot: squat, weightKg: 100, daysAgo: 80)
  let aboveBaseline = backfillLog(slot: squat, weightKg: 140, daysAgo: 70)
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let service = makeBackfill(
    logs: [belowBaseline, aboveBaseline],
    slots: [squat],
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: 150
  )

  let review = try #require(
    try await service.backfill(studentID: backfillStudentID).pendingReviews.first
  )
  var history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )
  #expect(history.first(where: { $0.setLogId == belowBaseline.id })?.confidence == .normal)
  #expect(history.first(where: { $0.setLogId == aboveBaseline.id })?.confidence == .low)

  try await service.answer(review, decision: .confirmed)
  history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )
  #expect(history.first(where: { $0.setLogId == aboveBaseline.id })?.confidence == .normal)
  #expect(try await service.backfill(studentID: backfillStudentID).pendingReviews.isEmpty)
}

@Test func rejectedBatchStaysLowWhenHigherBatchIsConfirmed() async throws {
  let squat = backfillSlot(family: .squat)
  let first = backfillLog(slot: squat, weightKg: 140, daysAgo: 80)
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let firstService = makeBackfill(
    logs: [first],
    slots: [squat],
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: 150
  )
  let firstReview = try #require(
    try await firstService.backfill(studentID: backfillStudentID).pendingReviews.first
  )
  try await firstService.answer(firstReview, decision: .rejected)

  let higher = backfillLog(slot: squat, weightKg: 160, daysAgo: 60)
  let secondService = makeBackfill(
    logs: [first, higher],
    slots: [squat],
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: 150
  )
  let secondReview = try #require(
    try await secondService.backfill(studentID: backfillStudentID).pendingReviews.first
  )
  #expect(secondReview.id != firstReview.id)
  try await secondService.answer(secondReview, decision: .confirmed)

  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )
  #expect(history.first(where: { $0.setLogId == first.id })?.confidence == .low)
  #expect(history.first(where: { $0.setLogId == higher.id })?.confidence == .normal)
}

@Test func newBatchAtOrBelowReviewedMaximumReusesDecision() async throws {
  let squat = backfillSlot(family: .squat)
  let first = backfillLog(slot: squat, weightKg: 160, daysAgo: 80)
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let firstService = makeBackfill(
    logs: [first],
    slots: [squat],
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: 150
  )
  let review = try #require(
    try await firstService.backfill(studentID: backfillStudentID).pendingReviews.first
  )
  try await firstService.answer(review, decision: .rejected)

  let lower = backfillLog(slot: squat, weightKg: 155, daysAgo: 60)
  let secondService = makeBackfill(
    logs: [first, lower],
    slots: [squat],
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: 150
  )
  let result = try await secondService.backfill(studentID: backfillStudentID)
  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )

  #expect(result.pendingReviews.isEmpty)
  #expect(history.first(where: { $0.setLogId == lower.id })?.confidence == .low)
}

@Test func missingBaselineImportsNormallyWithoutReview() async throws {
  let squat = backfillSlot(family: .squat)
  let log = backfillLog(slot: squat, weightKg: 180, daysAgo: 50)
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(logs: [log], slots: [squat], e1rm: e1rm)

  let result = try await service.backfill(studentID: backfillStudentID)
  let point = try #require(
    try await e1rm.fetchHistory(
      studentId: backfillStudentID,
      exerciseId: squat.exercise.id
    ).first
  )

  #expect(result.pendingReviews.isEmpty)
  #expect(point.confidence == .normal)
}

@Test func multipleFamiliesProduceOneStablePendingReviewEach() async throws {
  let squat = backfillSlot(family: .squat)
  let bench = backfillSlot(family: .bench)
  let deadlift = backfillSlot(family: .deadlift)
  let accessory = backfillSlot(family: nil)
  let logs = [
    backfillLog(slot: squat, weightKg: 160, daysAgo: 70),
    backfillLog(slot: bench, weightKg: 110, daysAgo: 60),
    backfillLog(slot: deadlift, weightKg: 180, reps: 3, daysAgo: 50),
    backfillLog(slot: accessory, weightKg: 200, daysAgo: 40),
  ]
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(
    logs: logs,
    slots: [squat, bench, deadlift, accessory],
    e1rm: e1rm,
    squatBaseline: 150,
    benchBaseline: 100,
    deadliftBaseline: 170
  )

  let result = try await service.backfill(studentID: backfillStudentID)
  let accessoryPoint = try #require(
    try await e1rm.fetchHistory(
      studentId: backfillStudentID,
      exerciseId: accessory.exercise.id
    ).first
  )

  #expect(result.pendingReviews.map(\.family) == [.bench, .deadlift, .squat])
  #expect(accessoryPoint.confidence == .normal)
}

@Test func replayPreservesExistingImportedPointConfidence() async throws {
  let squat = backfillSlot(family: .squat)
  let log = backfillLog(slot: squat, weightKg: 160, daysAgo: 70)
  let sourceWeightKg = NSDecimalNumber(decimal: log.weightKg).doubleValue
  let sourceRPE = log.rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
  let estimated = try #require(
    E1RMCalculator.calculate(weightKg: sourceWeightKg, reps: log.reps, rpe: sourceRPE)
  )
  let existing = E1RMHistoryPoint(
    id: UUID(),
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id,
    setLogId: log.id,
    computedAt: log.loggedAt,
    e1RMKg: estimated,
    sourceWeightKg: sourceWeightKg,
    sourceReps: log.reps,
    sourceRPE: sourceRPE,
    confidence: .low,
    origin: .imported
  )
  let e1rm = InMemoryE1RMRepository(seedPoints: [existing])
  let service = makeBackfill(
    logs: [log],
    slots: [squat],
    e1rm: e1rm,
    squatBaseline: 150
  )

  let result = try await service.backfill(studentID: backfillStudentID)
  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )

  #expect(history.count == 1)
  #expect(result.pendingReviews.isEmpty)
  #expect(history.first?.id == existing.id)
  #expect(history.first?.confidence == .low)
}

private struct BackfillSlot: Sendable {
  let planExerciseID: UUID
  let exercise: Exercise
}

@Test func concurrentBackfillsShareOneRunAndOnePendingReview() async throws {
  let squat = backfillSlot(family: .squat)
  let aboveBaseline = backfillLog(slot: squat, weightKg: 140, daysAgo: 70)
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let service = makeBackfill(
    logs: [aboveBaseline],
    slots: [squat],
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: 150
  )

  async let first = service.backfill(studentID: backfillStudentID)
  async let second = service.backfill(studentID: backfillStudentID)
  let results = try await [first, second]

  let reviewIDs = Set(results.compactMap { $0.pendingReviews.first?.id })
  #expect(reviewIDs.count == 1)
  let stored = try await reviews.pendingReview(studentID: backfillStudentID, family: .squat)
  #expect(stored?.id == reviewIDs.first)
  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )
  #expect(history.count == 1)
}

@Test func overlappingBackfillsExecuteThePipelineOnlyOnce() async throws {
  let squat = backfillSlot(family: .squat)
  let log = backfillLog(slot: squat, weightKg: 140, daysAgo: 70)
  let gated = GatedLogRepository(wrapping: InMemoryStudentTrainingLogRepository(seed: [log]))
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(logs: gated, slots: [squat], e1rm: e1rm)

  await gated.holdNextFetch()
  async let first = service.backfill(studentID: backfillStudentID)
  async let second = service.backfill(studentID: backfillStudentID)
  await gated.waitUntilHeld()
  await gated.releaseHeldFetch()
  _ = try await [first, second]

  // One 120-day window at 28-day slices = 5 fetches; a second pipeline run
  // would double this.
  #expect(await gated.fetchCallCount == 5)
}

@Test func answerDuringBackfillIsNotOverwrittenByStaleSnapshot() async throws {
  let squat = backfillSlot(family: .squat)
  let aboveBaseline = backfillLog(slot: squat, weightKg: 140, daysAgo: 70)
  let inMemoryLogs = InMemoryStudentTrainingLogRepository(seed: [aboveBaseline])
  let gated = GatedLogRepository(wrapping: inMemoryLogs)
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let service = makeBackfill(
    logs: gated,
    slots: [squat],
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: 150
  )

  let review = try #require(
    try await service.backfill(studentID: backfillStudentID).pendingReviews.first
  )

  await gated.holdNextFetch()
  async let replay = service.backfill(studentID: backfillStudentID)
  await gated.waitUntilHeld()
  async let answered: Void = service.answer(review, decision: .confirmed)
  await gated.releaseHeldFetch()
  _ = try await replay
  try await answered

  let history = try await e1rm.fetchHistory(
    studentId: backfillStudentID,
    exerciseId: squat.exercise.id
  )
  #expect(history.first(where: { $0.setLogId == aboveBaseline.id })?.confidence == .normal)
  #expect(try await reviews.pendingReview(studentID: backfillStudentID, family: .squat) == nil)
  let record = try await reviews.review(studentID: backfillStudentID, family: .squat)
  #expect(record?.decision == .confirmed)
}

/// Wraps a real repository and can hold the next `fetchLogs` on a gate so
/// tests can force overlap while counting pipeline executions.
private actor GatedLogRepository: StudentTrainingLogRepository {
  private let wrapped: any StudentTrainingLogRepository
  private(set) var fetchCallCount = 0
  private var holdArmed = false
  private var heldContinuation: CheckedContinuation<Void, Never>?
  private var heldObservers: [CheckedContinuation<Void, Never>] = []

  init(wrapping wrapped: any StudentTrainingLogRepository) {
    self.wrapped = wrapped
  }

  func holdNextFetch() {
    holdArmed = true
  }

  func waitUntilHeld() async {
    guard heldContinuation == nil else { return }
    await withCheckedContinuation { heldObservers.append($0) }
  }

  func releaseHeldFetch() {
    heldContinuation?.resume()
    heldContinuation = nil
  }

  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    try await wrapped.recordSet(log)
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    fetchCallCount += 1
    if holdArmed {
      holdArmed = false
      await withCheckedContinuation { continuation in
        heldContinuation = continuation
        for observer in heldObservers {
          observer.resume()
        }
        heldObservers = []
      }
    }
    return try await wrapped.fetchLogs(studentID: studentID, in: dateRange)
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    try await wrapped.fetchLogsForExercise(studentID: studentID, planExerciseID: planExerciseID)
  }
}

private func backfillSlot(family: LiftFamily?) -> BackfillSlot {
  BackfillSlot(
    planExerciseID: UUID(),
    exercise: Exercise(
      id: UUID(),
      name: "测试动作",
      exerciseType: family == nil ? .accessory : .mainLift,
      mainLiftFamily: family,
      isCompetitionLift: family != nil,
      muscleGroups: [.quad],
      equipment: [.barbell],
      createdAt: backfillNow
    )
  )
}

private func backfillLog(
  slot: BackfillSlot,
  exerciseID: UUID? = nil,
  weightKg: Decimal,
  reps: Int = 5,
  rpe: Decimal? = 8,
  daysAgo: Int,
  completed: Bool = true,
  failed: Bool = false,
  assumed: Bool = true
) -> StudentSetLog {
  backfillLog(
    planExerciseID: slot.planExerciseID,
    exerciseID: exerciseID,
    weightKg: weightKg,
    reps: reps,
    rpe: rpe,
    daysAgo: daysAgo,
    completed: completed,
    failed: failed,
    assumed: assumed
  )
}

private func backfillLog(
  planExerciseID: UUID,
  exerciseID: UUID? = nil,
  weightKg: Decimal,
  reps: Int = 5,
  rpe: Decimal? = 8,
  daysAgo: Int,
  completed: Bool = true,
  failed: Bool = false,
  assumed: Bool = true
) -> StudentSetLog {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
  let loggedAt = calendar.date(byAdding: .day, value: -daysAgo, to: backfillNow) ?? backfillNow
  return StudentSetLog(
    id: UUID(),
    studentID: backfillStudentID,
    planExerciseID: planExerciseID,
    exerciseID: exerciseID,
    setIndex: daysAgo,
    loggedAt: loggedAt,
    weightKg: weightKg,
    reps: reps,
    rpe: rpe,
    completed: completed,
    failed: failed,
    assumed: assumed
  )
}

private func makeBackfill(
  logs: [StudentSetLog],
  slots: [BackfillSlot],
  planSlots: [BackfillSlot]? = nil,
  e1rm: any E1RMRepository,
  reviews: any ImportedHistoryReviewStoring = InMemoryImportedHistoryReviewStore(),
  squatBaseline: Decimal? = nil,
  benchBaseline: Decimal? = nil,
  deadliftBaseline: Decimal? = nil
) -> ImportedHistoryBackfill {
  makeBackfill(
    logs: InMemoryStudentTrainingLogRepository(seed: logs),
    slots: slots,
    planSlots: planSlots,
    e1rm: e1rm,
    reviews: reviews,
    squatBaseline: squatBaseline,
    benchBaseline: benchBaseline,
    deadliftBaseline: deadliftBaseline
  )
}

private func makeBackfill(
  logs: any StudentTrainingLogRepository,
  slots: [BackfillSlot],
  planSlots: [BackfillSlot]? = nil,
  e1rm: any E1RMRepository,
  reviews: any ImportedHistoryReviewStoring = InMemoryImportedHistoryReviewStore(),
  squatBaseline: Decimal? = nil,
  benchBaseline: Decimal? = nil,
  deadliftBaseline: Decimal? = nil
) -> ImportedHistoryBackfill {
  let resolvedPlanSlots = planSlots ?? slots
  let profile = OnboardingProfile(
    userId: backfillStudentID,
    squat1RMKg: squatBaseline,
    bench1RMKg: benchBaseline,
    deadlift1RMKg: deadliftBaseline,
    createdAt: backfillNow,
    updatedAt: backfillNow
  )
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: backfillNow,
    days: resolvedPlanSlots.isEmpty
      ? []
      : [
        StudentPlanDay(
          id: UUID(),
          date: backfillNow,
          exercises: resolvedPlanSlots.enumerated().map { index, slot in
            StudentPlanExercise(
              id: slot.planExerciseID,
              exercise: slot.exercise,
              sequenceIndex: index,
              prescribedSets: []
            )
          }
        )
      ]
  )
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
  return ImportedHistoryBackfill(
    logs: logs,
    onboarding: InMemoryOnboardingRepository(studentId: backfillStudentID, seed: profile),
    plans: BackfillPlanRepository(plan: plan),
    catalogReader: BackfillCatalogReader(exercises: slots.map(\.exercise)),
    e1rm: e1rm,
    reviews: reviews,
    now: { backfillNow },
    calendar: calendar
  )
}

private struct BackfillCatalogReader: ExerciseCatalogReading {
  let exercises: [Exercise]

  func fetchExerciseCatalog() async throws -> [Exercise] {
    exercises
  }
}

private struct BackfillPlanRepository: StudentPlanRepository {
  let plan: StudentPlanView

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    plan
  }

  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    plan.days.first
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    plan.days
  }
}
