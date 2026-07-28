import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

/// Spec 028 §4: the e1RM/PR hook fires inside the persist path on the
/// false→true completion edge only.
///
/// All clocks in this file are frozen to a UTC midnight. The demo seed
/// anchors plan-day dates at UTC midnights while the view model matches
/// "today" with `Calendar.current`, so a live `Date()` resolves the wrong
/// day whenever the local calendar day differs from the UTC one (e.g.
/// 00:00–08:00 Beijing). Freezing to the seed's own anchor makes
/// `day[3].date == frozenNow` — the same absolute instant is same-day with
/// itself in any calendar, so day-offset 3 (硬拉 day) resolves everywhere.
private let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)  // 2026-01-13 00:00:00 UTC

@MainActor
private func makeLoadedViewModel(
  e1rm: InMemoryE1RMRepository
) async throws -> (TodayWorkoutViewModel, UUID) {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView(today: frozenNow)
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: e1rm,
    now: { frozenNow }
  )
  // Demo cycle anchors "today" at day-offset 3 (硬拉 day).
  await viewModel.load(date: frozenNow, studentID: studentID)
  guard case .loaded = viewModel.state else {
    throw TestFailure("expected loaded state, got \(viewModel.state)")
  }
  return (viewModel, studentID)
}

private struct TestFailure: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

@MainActor
@Test func firstCompletionRecordsPointAndDetectsPR() async throws {
  let e1rm = InMemoryE1RMRepository()
  let (viewModel, studentID) = try await makeLoadedViewModel(e1rm: e1rm)
  guard case .loaded(_, let drafts) = viewModel.state, let first = drafts.first else {
    throw TestFailure("no drafts")
  }

  await viewModel.toggleComplete(rowIndex: 0)

  let history = try await e1rm.fetchHistory(studentId: studentID, exerciseId: first.exerciseID)
  #expect(history.count == 1)
  // Empty history → any first point is a PR (previousMax 0).
  #expect(viewModel.pendingPRBanner != nil)
  #expect(viewModel.pendingPRBanner?.exerciseId == first.exerciseID)
  let pending = try await e1rm.unacknowledgedPRs(studentId: studentID)
  #expect(pending.count == 1)
}

@MainActor
@Test func failedCompletionDoesNotRecordPointOrDetectPR() async throws {
  let e1rm = InMemoryE1RMRepository()
  let (viewModel, studentID) = try await makeLoadedViewModel(e1rm: e1rm)
  guard case .loaded(_, let drafts) = viewModel.state, let first = drafts.first else {
    throw TestFailure("no drafts")
  }

  await viewModel.commitSet(rowIndex: 0, failed: true)

  guard case .loaded(_, let updated) = viewModel.state else {
    throw TestFailure("expected loaded state after failed commit")
  }
  #expect(updated[0].completed)
  #expect(updated[0].failed)
  let history = try await e1rm.fetchHistory(studentId: studentID, exerciseId: first.exerciseID)
  #expect(history.isEmpty)
  #expect(viewModel.pendingPRBanner == nil)
  let pending = try await e1rm.unacknowledgedPRs(studentId: studentID)
  #expect(pending.isEmpty)
}

@MainActor
@Test func lowRPECompletionUsesSegmentedCalculatorAndRecordsE1RM() async throws {
  let e1rm = InMemoryE1RMRepository()
  let (viewModel, studentID) = try await makeLoadedViewModel(e1rm: e1rm)
  guard case .loaded(_, let drafts) = viewModel.state, let first = drafts.first else {
    throw TestFailure("no drafts")
  }

  viewModel.updateRPE(rowIndex: 0, rpe: 6)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .loaded(_, let updated) = viewModel.state else {
    throw TestFailure("expected loaded state after completion")
  }
  #expect(updated[0].completed)
  let history = try await e1rm.fetchHistory(studentId: studentID, exerciseId: first.exerciseID)
  #expect(history.count == 1)
  #expect(history.first?.sourceRPE == 6)
  #expect(
    history.first?.e1RMKg
      == E1RMCalculator.calculate(
        weightKg: NSDecimalNumber(decimal: updated[0].actualWeight ?? 0).doubleValue,
        reps: updated[0].actualReps ?? 0,
        rpe: 6
      ))
}

@MainActor
@Test func uncheckingThenRecheckingDoesNotFarmDuplicatePRs() async throws {
  let e1rm = InMemoryE1RMRepository()
  let (viewModel, studentID) = try await makeLoadedViewModel(e1rm: e1rm)
  guard case .loaded(_, let drafts) = viewModel.state, let first = drafts.first else {
    throw TestFailure("no drafts")
  }

  await viewModel.toggleComplete(rowIndex: 0)  // false → true: hook fires
  await viewModel.acknowledgePendingPR()
  await viewModel.toggleComplete(rowIndex: 0)  // true → false: no hook
  await viewModel.toggleComplete(rowIndex: 0)  // false → true again: hook fires

  let history = try await e1rm.fetchHistory(studentId: studentID, exerciseId: first.exerciseID)
  #expect(history.count == 1)
  // Rechecking upserts the same set-log point; identical measured weight does
  // not create another PR.
  let pending = try await e1rm.unacknowledgedPRs(studentId: studentID)
  #expect(pending.isEmpty)
  #expect(viewModel.pendingPRBanner == nil)
}

@MainActor
@Test func e1RMImprovementAtTheSameMeasuredWeightDoesNotFirePR() async throws {
  let e1rm = InMemoryE1RMRepository()
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView(today: frozenNow)
  guard let deadlift = plan.days[3].exercises.first?.exercise else {
    throw TestFailure("seed shape changed")
  }
  // Seed the same measured weight with a slightly lower e1RM. Today's
  // projected estimate improves, but 175 kg itself is not a weight PR.
  try await e1rm.recordPoint(
    E1RMHistoryPoint(
      id: UUID(), studentId: studentID, exerciseId: deadlift.id, family: .deadlift,
      setLogId: UUID(),
      computedAt: frozenNow.addingTimeInterval(-86_400),
      e1RMKg: 203.3, sourceWeightKg: 175, sourceReps: 3, sourceRPE: 8.5
    ))
  try await e1rm.recordWeightBaseline(
    E1RMWeightBaseline(
      studentId: studentID,
      family: .deadlift,
      maxWeightKg: 175,
      setLogId: UUID(),
      achievedAt: frozenNow.addingTimeInterval(-86_400)
    )
  )

  let (viewModel, _) = try await makeLoadedViewModel(e1rm: e1rm)
  await viewModel.toggleComplete(rowIndex: 0)

  let history = try await e1rm.fetchHistory(studentId: studentID, exerciseId: deadlift.id)
  #expect(history.count == 2, "point still recorded")
  #expect(viewModel.pendingPRBanner == nil, "e1RM extrapolation alone must not fire a PR")
}

@MainActor
@Test func surfaceUnacknowledgedPROnLaunch() async throws {
  let studentID = StudentDemoSeed.studentID
  let e1rm = InMemoryE1RMRepository(
    seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: studentID),
    seedPRs: StudentDemoSeed.makeUnacknowledgedPR(studentID: studentID)
  )
  let (viewModel, _) = try await makeLoadedViewModel(e1rm: e1rm)

  #expect(viewModel.pendingPRBanner == nil)
  await viewModel.surfaceUnacknowledgedPR(studentID: studentID)
  #expect(viewModel.pendingPRBanner != nil)

  await viewModel.acknowledgePendingPR()
  #expect(viewModel.pendingPRBanner == nil)
  await viewModel.surfaceUnacknowledgedPR(studentID: studentID)
  #expect(viewModel.pendingPRBanner == nil, "acknowledged PR must not re-surface")
}

@MainActor
@Test func sameTimestampCompletionsDoNotDoubleFirePRs() async throws {
  // Frozen clock: both completions get identical computedAt. The baseline is
  // taken over the full history before insertion (Codex review P1), so the
  // second identical measured-weight set must not create another PR.
  let e1rm = InMemoryE1RMRepository()
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView(today: frozenNow)
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: e1rm,
    now: { frozenNow }
  )
  await viewModel.load(date: frozenNow, studentID: studentID)

  await viewModel.toggleComplete(rowIndex: 0)
  await viewModel.acknowledgePendingPR()
  await viewModel.toggleComplete(rowIndex: 1)  // same prescription, same instant

  #expect(viewModel.pendingPRBanner == nil, "identical e1RM at the same instant is not a PR")
  let pending = try await e1rm.unacknowledgedPRs(studentId: studentID)
  #expect(pending.isEmpty)
}
