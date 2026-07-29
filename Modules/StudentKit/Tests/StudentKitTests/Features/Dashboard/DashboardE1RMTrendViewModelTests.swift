import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func trendHeadlineUsesLatestUnacknowledgedPRFamily() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let benchID = try #require(plan.mainLiftID(for: .bench))
  let deadliftID = try #require(plan.mainLiftID(for: .deadlift))
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let points = [
    point(studentID: studentID, exerciseID: benchID, e1RM: 100, daysAgo: 5, now: now),
    point(studentID: studentID, exerciseID: deadliftID, e1RM: 180, daysAgo: 3, now: now),
  ]
  let prs = [
    pr(studentID: studentID, exerciseID: deadliftID, e1RM: 180, daysAgo: 2, now: now),
    pr(studentID: studentID, exerciseID: benchID, e1RM: 101, daysAgo: 1, now: now),
  ]

  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: points, prs: prs, now: now)
  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  #expect(presentation.rows.map(\.family) == [.squat, .bench, .deadlift])
  #expect(presentation.headline?.kind == .latestPR)
  #expect(presentation.headline?.family == .bench)
  #expect(presentation.headline?.valueKg == 101)
}

@MainActor
@Test func trendHeadlineFallsBackToBestCurrentE1RM() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let deadliftID = try #require(plan.mainLiftID(for: .deadlift))
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let points = [
    point(studentID: studentID, exerciseID: squatID, e1RM: 150, daysAgo: 5, now: now),
    point(studentID: studentID, exerciseID: deadliftID, e1RM: 190, daysAgo: 2, now: now),
  ]

  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: points, prs: [], now: now)
  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  #expect(presentation.headline?.kind == .best)
  #expect(presentation.headline?.family == .deadlift)
  #expect(presentation.headline?.valueKg == 190)
}

@MainActor
@Test func trendHeadlineUsesHistoricalBestWhenRollingWindowHasExpired() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let now = try Date("2026-07-09T12:00:00Z", strategy: .iso8601)
  let imported = E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: squatID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(-84 * 86_400),
    e1RMKg: 165,
    sourceWeightKg: 140,
    sourceReps: 5,
    sourceRPE: 8,
    origin: .imported
  )
  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: [imported], prs: [], now: now)

  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  let squatRow = try #require(presentation.rows.first { $0.family == .squat })
  #expect(presentation.headline?.kind == .historicalBest)
  #expect(presentation.headline?.valueKg == 165)
  #expect(squatRow.displayPoint(now: now)?.id == imported.id)
}

@MainActor
@Test func trendHeadlineAndRowsUseRecordTrajectory() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let points = [
    point(studentID: studentID, exerciseID: squatID, e1RM: 180, daysAgo: 10, now: now),
    point(studentID: studentID, exerciseID: squatID, e1RM: 175, daysAgo: 1, now: now),
  ]

  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: points, prs: [], now: now)
  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  // Product amendment: the lower recent training point is no longer drawn;
  // the real record is carried forward to today instead.
  #expect(squat.points.map(\.e1RMKg) == [180, 180])
  #expect(squat.latestPoint?.e1RMKg == 180)
  #expect(presentation.headline?.kind == .best)
  #expect(presentation.headline?.valueKg == 180)
}

@MainActor
@Test func recentTrainingWithoutARecordStillDisplaysHistoricalBest() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let now = try Date("2026-07-09T12:00:00Z", strategy: .iso8601)
  let oldRecord = point(
    studentID: studentID, exerciseID: squatID, e1RM: 180, daysAgo: 60, now: now)
  let recentTraining = point(
    studentID: studentID, exerciseID: squatID, e1RM: 175, daysAgo: 1, now: now)
  let viewModel = makeViewModel(
    studentID: studentID,
    plan: plan,
    points: [oldRecord, recentTraining],
    prs: [],
    now: now
  )

  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  #expect(squat.displaysHistoricalBest(now: now))
  #expect(squat.displayPoint(now: now)?.id == oldRecord.id)
  #expect(squat.displayPoint(now: now)?.e1RMKg == 180)
  #expect(squat.trendDeltaKg == 0)
  #expect(presentation.headline?.kind == .historicalBest)
}

@MainActor
@Test func recordWithinFourWeeksDisplaysBestAndCurrentRecordValue() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let now = try Date("2026-07-09T12:00:00Z", strategy: .iso8601)
  let points = [
    point(studentID: studentID, exerciseID: squatID, e1RM: 170, daysAgo: 60, now: now),
    point(studentID: studentID, exerciseID: squatID, e1RM: 180, daysAgo: 10, now: now),
    point(studentID: studentID, exerciseID: squatID, e1RM: 175, daysAgo: 1, now: now),
  ]
  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: points, prs: [], now: now)

  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  #expect(!squat.displaysHistoricalBest(now: now))
  #expect(squat.displayPoint(now: now)?.e1RMKg == 180)
  #expect(squat.points.map(\.e1RMKg) == [170, 180, 180])
  #expect(presentation.headline?.kind == .best)
  #expect(presentation.headline?.valueKg == 180)
}

@MainActor
@Test func trendRawLayerOnlyContainsLowConfidencePoints() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let now = try Date("2026-07-09T12:00:00Z", strategy: .iso8601)
  let trusted = point(
    studentID: studentID, exerciseID: squatID, e1RM: 170, daysAgo: 10, now: now)
  let low = E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: squatID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(-86_400),
    e1RMKg: 200,
    sourceWeightKg: 180,
    sourceReps: 3,
    sourceRPE: 8,
    confidence: .low,
    origin: .imported
  )
  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: [trusted, low], prs: [], now: now)

  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  #expect(squat.rawEligiblePoints.map(\.id) == [low.id])
}

@MainActor
@Test func trendUsesNinetyDayCarryAsDeltaBaseline() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let now = try Date("2026-07-09T12:00:00Z", strategy: .iso8601)
  let allTimeRecord = point(
    studentID: studentID, exerciseID: squatID, e1RM: 100, daysAgo: 200, now: now)
  let preWindowRecord = point(
    studentID: studentID, exerciseID: squatID, e1RM: 140, daysAgo: 100, now: now)
  let inWindowRecord = point(
    studentID: studentID, exerciseID: squatID, e1RM: 150, daysAgo: 10, now: now)
  let viewModel = makeViewModel(
    studentID: studentID,
    plan: plan,
    points: [allTimeRecord, preWindowRecord, inWindowRecord],
    prs: [],
    now: now
  )

  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  let windowStart = now.addingTimeInterval(
    -TimeInterval(DashboardE1RMTrendViewModel.chartWindowDays) * 86_400
  )
  #expect(squat.smoothedSamples.map(\.valueKg) == [140, 150, 150])
  #expect(squat.smoothedSamples.first?.date == windowStart)
  #expect(squat.smoothedSamples.first?.winnerPointID == preWindowRecord.id)
  #expect(squat.points.map(\.e1RMKg) == [140, 150, 150])
  #expect(squat.trendDeltaKg == 10)
  #expect(squat.latestRecordPoint?.id == inWindowRecord.id)

  // Rising-line rendering (David 2026-07-17): records connect directly,
  // no inserted step corners; the carry sample keeps the flat tail.
  let sparkline = squat.sparklinePoints()
  #expect(sparkline.count == 3)
  #expect(sparkline[0].y > sparkline[1].y)
  #expect(sparkline[1].y == sparkline[2].y)
}

@MainActor
@Test func trendEmptyHistoryKeepsThreeRowsWithoutHeadline() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: [], prs: [], now: now)

  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  #expect(presentation.rows.count == 3)
  #expect(!presentation.hasHistory)
  #expect(presentation.rows.allSatisfy { $0.trendState == .zero })
  #expect(presentation.rows.allSatisfy { $0.eligibleRecordCount == 0 })
  #expect(presentation.headline == nil)
}

@MainActor
@Test func trendHeadlineSkipsUnresolvablePRToOlderMainLiftPR() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let benchID = try #require(plan.mainLiftID(for: .bench))
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let points = [
    point(studentID: studentID, exerciseID: benchID, e1RM: 100, daysAgo: 5, now: now)
  ]
  let prs = [
    // Newest PR is for an exercise not in the current plan (e.g. an accessory) —
    // unresolvable, must not hide the older resolvable bench PR.
    pr(studentID: studentID, exerciseID: UUID(), e1RM: 70, daysAgo: 1, now: now),
    pr(studentID: studentID, exerciseID: benchID, e1RM: 101, daysAgo: 3, now: now),
  ]

  let viewModel = makeViewModel(
    studentID: studentID, plan: plan, points: points, prs: prs, now: now)
  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  #expect(presentation.headline?.kind == .latestPR)
  #expect(presentation.headline?.family == .bench)
  #expect(presentation.headline?.valueKg == 101)
}

@MainActor
private func makeViewModel(
  studentID: UUID,
  plan: StudentPlanView,
  points: [E1RMHistoryPoint],
  prs: [PRBreakthroughEvent],
  now: Date
) -> DashboardE1RMTrendViewModel {
  DashboardE1RMTrendViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    e1rm: InMemoryE1RMRepository(seedPoints: points, seedPRs: prs),
    now: { now }
  )
}

private func point(
  studentID: UUID,
  exerciseID: UUID,
  e1RM: Double,
  daysAgo: Int,
  now: Date
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: exerciseID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(Double(-daysAgo) * 86_400),
    e1RMKg: e1RM,
    sourceWeightKg: e1RM * 0.88,
    sourceReps: 5,
    sourceRPE: 8
  )
}

private func pr(
  studentID: UUID,
  exerciseID: UUID,
  e1RM: Double,
  daysAgo: Int,
  now: Date
) -> PRBreakthroughEvent {
  PRBreakthroughEvent(
    id: UUID(),
    studentId: studentID,
    exerciseId: exerciseID,
    pointId: UUID(),
    breakthroughE1RMKg: e1RM,
    previousMaxE1RMKg: e1RM - 2.5,
    occurredAt: now.addingTimeInterval(Double(-daysAgo) * 86_400),
    acknowledgedAt: nil
  )
}

extension DashboardE1RMTrendViewModel {
  fileprivate var presentation: DashboardE1RMTrendPresentation? {
    guard case .loaded(let presentation) = state else {
      return nil
    }
    return presentation
  }
}

extension StudentPlanView {
  fileprivate func mainLiftID(for family: LiftFamily) -> UUID? {
    guard
      let slot = days.flatMap(\.exercises).first(where: {
        $0.exercise.exerciseType == .mainLift && $0.exercise.mainLiftFamily == family
      })
    else {
      return nil
    }
    return slot.exercise.id
  }
}
