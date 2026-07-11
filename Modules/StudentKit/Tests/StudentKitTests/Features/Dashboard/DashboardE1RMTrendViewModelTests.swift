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

  let viewModel = makeViewModel(studentID: studentID, plan: plan, points: points, prs: prs)
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

  let viewModel = makeViewModel(studentID: studentID, plan: plan, points: points, prs: [])
  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  #expect(presentation.headline?.kind == .best)
  #expect(presentation.headline?.family == .deadlift)
  #expect(presentation.headline?.valueKg == 190)
}

@MainActor
@Test func trendHeadlineAndRowsUseRollingWindowMaximum() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftID(for: .squat))
  let now = try Date("2026-06-14T12:00:00Z", strategy: .iso8601)
  let points = [
    point(studentID: studentID, exerciseID: squatID, e1RM: 180, daysAgo: 10, now: now),
    point(studentID: studentID, exerciseID: squatID, e1RM: 175, daysAgo: 1, now: now),
  ]

  let viewModel = makeViewModel(studentID: studentID, plan: plan, points: points, prs: [])
  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  #expect(squat.points.map(\.e1RMKg) == [180, 180])
  #expect(squat.latestPoint?.e1RMKg == 180)
  #expect(presentation.headline?.valueKg == 180)
}

@MainActor
@Test func trendEmptyHistoryKeepsThreeRowsWithoutHeadline() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let viewModel = makeViewModel(studentID: studentID, plan: plan, points: [], prs: [])

  await viewModel.load(studentID: studentID)

  let presentation = try #require(viewModel.presentation)
  #expect(presentation.rows.count == 3)
  #expect(!presentation.hasHistory)
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

  let viewModel = makeViewModel(studentID: studentID, plan: plan, points: points, prs: prs)
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
  prs: [PRBreakthroughEvent]
) -> DashboardE1RMTrendViewModel {
  DashboardE1RMTrendViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    e1rm: InMemoryE1RMRepository(seedPoints: points, seedPRs: prs)
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
