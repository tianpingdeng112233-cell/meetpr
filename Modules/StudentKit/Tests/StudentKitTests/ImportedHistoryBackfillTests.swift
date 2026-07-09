import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private let backfillStudentID = UUID()
private let backfillNow = Date(timeIntervalSince1970: 1_783_468_800)  // 2026-07-09 UTC

@Test func importedHistoryBackfillFiltersEligibilityUsesLoggedAtAndIsIdempotent() async throws {
  let squat = backfillExercise(family: .squat)
  let deadlift = backfillExercise(family: .deadlift)
  let eligible = backfillLog(exerciseID: squat.id, weightKg: 140, reps: 5, rpe: 8, daysAgo: 80)
  let lowRPE = backfillLog(exerciseID: squat.id, weightKg: 140, reps: 5, rpe: 6, daysAgo: 70)
  let highRep = backfillLog(exerciseID: squat.id, weightKg: 100, reps: 11, rpe: 8, daysAgo: 60)
  let deadliftSix = backfillLog(
    exerciseID: deadlift.id, weightKg: 160, reps: 6, rpe: 8, daysAgo: 50)
  let noExercise = backfillLog(exerciseID: nil, weightKg: 140, reps: 5, rpe: 8, daysAgo: 40)
  let repository = InMemoryStudentTrainingLogRepository(
    seed: [eligible, lowRPE, highRep, deadliftSix, noExercise])
  let e1rm = InMemoryE1RMRepository()
  let service = makeBackfill(logs: repository, e1rm: e1rm, catalog: [squat, deadlift])

  let first = try await service.backfill(studentID: backfillStudentID)
  let second = try await service.backfill(studentID: backfillStudentID)
  let history = try await e1rm.fetchHistory(studentId: backfillStudentID, exerciseId: squat.id)

  #expect(first.importedPointCount == 1)
  #expect(second.importedPointCount == 1)
  #expect(history.count == 1)
  #expect(history.first?.origin == .imported)
  #expect(history.first?.computedAt == eligible.loggedAt)
  let events = try await e1rm.unacknowledgedPRs(studentId: backfillStudentID)
  #expect(events.isEmpty)
}

@Test func importedHistoryReviewPromotesOnlyConfirmedBatchAndDoesNotRepromptReplay() async throws {
  let squat = backfillExercise(family: .squat)
  let trusted = backfillLog(exerciseID: squat.id, weightKg: 100, reps: 5, rpe: 8, daysAgo: 80)
  let aboveBaseline = backfillLog(exerciseID: squat.id, weightKg: 140, reps: 5, rpe: 8, daysAgo: 70)
  let logs = InMemoryStudentTrainingLogRepository(seed: [trusted, aboveBaseline])
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let service = makeBackfill(
    logs: logs,
    e1rm: e1rm,
    reviews: reviews,
    catalog: [squat],
    squatBaseline: 150
  )

  let result = try await service.backfill(studentID: backfillStudentID)
  let review = try #require(result.pendingReviews.first)
  var history = try await e1rm.fetchHistory(studentId: backfillStudentID, exerciseId: squat.id)
  #expect(history.count == 2)
  #expect(history.first(where: { $0.setLogId == trusted.id })?.confidence == .normal)
  #expect(history.first(where: { $0.setLogId == aboveBaseline.id })?.confidence == .low)

  try await service.answer(review, decision: .confirmed)
  history = try await e1rm.fetchHistory(studentId: backfillStudentID, exerciseId: squat.id)
  #expect(history.first(where: { $0.setLogId == aboveBaseline.id })?.confidence == .normal)
  #expect((try await service.backfill(studentID: backfillStudentID)).pendingReviews.isEmpty)
}

@Test
func higherImportedBatchReopensReviewWithoutRewritingRejectedBatchAndNilBaselineStopsPrompting()
  async throws
{
  let squat = backfillExercise(family: .squat)
  let first = backfillLog(exerciseID: squat.id, weightKg: 140, reps: 5, rpe: 8, daysAgo: 80)
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let firstService = makeBackfill(
    logs: InMemoryStudentTrainingLogRepository(seed: [first]),
    e1rm: e1rm,
    reviews: reviews,
    catalog: [squat],
    squatBaseline: 150
  )
  let firstResult = try await firstService.backfill(studentID: backfillStudentID)
  let firstReview = try #require(firstResult.pendingReviews.first)
  try await firstService.answer(firstReview, decision: .rejected)

  let higher = backfillLog(exerciseID: squat.id, weightKg: 160, reps: 5, rpe: 8, daysAgo: 60)
  let secondService = makeBackfill(
    logs: InMemoryStudentTrainingLogRepository(seed: [first, higher]),
    e1rm: e1rm,
    reviews: reviews,
    catalog: [squat],
    squatBaseline: 150
  )
  let secondReview = try #require(
    (try await secondService.backfill(studentID: backfillStudentID)).pendingReviews.first)
  try await secondService.answer(secondReview, decision: .confirmed)

  var history = try await e1rm.fetchHistory(studentId: backfillStudentID, exerciseId: squat.id)
  #expect(history.first(where: { $0.setLogId == first.id })?.confidence == .low)
  #expect(history.first(where: { $0.setLogId == higher.id })?.confidence == .normal)

  let noBaseline = backfillLog(exerciseID: squat.id, weightKg: 170, reps: 5, rpe: 8, daysAgo: 40)
  let nilBaselineService = makeBackfill(
    logs: InMemoryStudentTrainingLogRepository(seed: [first, higher, noBaseline]),
    e1rm: e1rm,
    reviews: reviews,
    catalog: [squat]
  )
  let nilResult = try await nilBaselineService.backfill(studentID: backfillStudentID)
  history = try await e1rm.fetchHistory(studentId: backfillStudentID, exerciseId: squat.id)
  #expect(nilResult.pendingReviews.isEmpty)
  #expect(history.first(where: { $0.setLogId == noBaseline.id })?.confidence == .normal)
}

@Test func distinctNewBatchAtOrBelowReviewedMaxReusesDecisionWithoutReprompt() async throws {
  let squat = backfillExercise(family: .squat)
  let first = backfillLog(exerciseID: squat.id, weightKg: 160, reps: 5, rpe: 8, daysAgo: 80)
  let e1rm = InMemoryE1RMRepository()
  let reviews = InMemoryImportedHistoryReviewStore()
  let firstService = makeBackfill(
    logs: InMemoryStudentTrainingLogRepository(seed: [first]),
    e1rm: e1rm,
    reviews: reviews,
    catalog: [squat],
    squatBaseline: 150
  )
  let review = try #require(
    (try await firstService.backfill(studentID: backfillStudentID)).pendingReviews.first)
  try await firstService.answer(review, decision: .rejected)

  // A *distinct* later batch whose max stays at or below the reviewed max
  // reuses the stored decision — no re-prompt, straight to `.low` (spec 053 §5).
  let lower = backfillLog(exerciseID: squat.id, weightKg: 155, reps: 5, rpe: 8, daysAgo: 60)
  let secondService = makeBackfill(
    logs: InMemoryStudentTrainingLogRepository(seed: [first, lower]),
    e1rm: e1rm,
    reviews: reviews,
    catalog: [squat],
    squatBaseline: 150
  )
  let result = try await secondService.backfill(studentID: backfillStudentID)
  #expect(result.pendingReviews.isEmpty)
  let history = try await e1rm.fetchHistory(studentId: backfillStudentID, exerciseId: squat.id)
  #expect(history.first(where: { $0.setLogId == lower.id })?.confidence == .low)
}

@Test func multiFamilyImportProducesOnePendingReviewPerFamily() async throws {
  let squat = backfillExercise(family: .squat)
  let bench = backfillExercise(family: .bench)
  let squatHigh = backfillLog(exerciseID: squat.id, weightKg: 160, reps: 5, rpe: 8, daysAgo: 70)
  let benchHigh = backfillLog(exerciseID: bench.id, weightKg: 110, reps: 5, rpe: 8, daysAgo: 60)
  let service = makeBackfill(
    logs: InMemoryStudentTrainingLogRepository(seed: [squatHigh, benchHigh]),
    e1rm: InMemoryE1RMRepository(),
    catalog: [squat, bench],
    squatBaseline: 150,
    benchBaseline: 100
  )

  let result = try await service.backfill(studentID: backfillStudentID)
  #expect(result.pendingReviews.count == 2)
  #expect(Set(result.pendingReviews.map(\.family)) == [.squat, .bench])
}

private func makeBackfill(
  logs: any StudentTrainingLogRepository,
  e1rm: any E1RMRepository,
  reviews: any ImportedHistoryReviewStoring = InMemoryImportedHistoryReviewStore(),
  catalog: [Exercise],
  squatBaseline: Decimal? = nil,
  benchBaseline: Decimal? = nil
) -> ImportedHistoryBackfill {
  let profile: OnboardingProfile? =
    (squatBaseline != nil || benchBaseline != nil)
    ? OnboardingProfile(
      userId: backfillStudentID,
      squat1RMKg: squatBaseline,
      bench1RMKg: benchBaseline,
      createdAt: backfillNow,
      updatedAt: backfillNow
    )
    : nil
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
  return ImportedHistoryBackfill(
    logs: logs,
    onboarding: InMemoryOnboardingRepository(studentId: backfillStudentID, seed: profile),
    e1rm: e1rm,
    reviews: reviews,
    catalog: catalog,
    now: { backfillNow },
    calendar: calendar
  )
}

private func backfillExercise(family: LiftFamily) -> Exercise {
  Exercise(
    id: UUID(), name: family.studentDisplayName, nameEn: family.studentDisplayName,
    exerciseType: .mainLift, mainLiftFamily: family, isCompetitionLift: true,
    muscleGroups: [.quad], equipment: [.barbell], createdAt: backfillNow)
}

private func backfillLog(
  exerciseID: UUID?,
  weightKg: Decimal,
  reps: Int,
  rpe: Decimal?,
  daysAgo: Int
) -> StudentSetLog {
  let loggedAt = backfillNow.addingTimeInterval(Double(-daysAgo) * 86_400)
  return StudentSetLog(
    id: UUID(),
    studentID: backfillStudentID,
    planExerciseID: UUID(),
    exerciseID: exerciseID,
    loggedDate: loggedAt.formatted(.iso8601.year().month().day()),
    assumed: true,
    setIndex: 0,
    loggedAt: loggedAt,
    weightKg: weightKg,
    reps: reps,
    rpe: rpe,
    completed: true
  )
}
