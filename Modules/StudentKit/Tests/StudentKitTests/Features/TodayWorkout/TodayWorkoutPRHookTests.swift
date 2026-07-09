import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

/// Spec 028 §4: the e1RM/PR hook fires inside the persist path on the
/// false→true completion edge only.
@MainActor
private func makeLoadedViewModel(
  e1rm: InMemoryE1RMRepository
) async throws -> (TodayWorkoutViewModel, UUID) {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: e1rm
  )
  // Demo cycle anchors "today" at day-offset 3 (硬拉 day).
  await viewModel.load(date: Date(), studentID: studentID)
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
  // A recheck rewrites the same persisted set-log point instead of adding a
  // second history point (spec 053 §3).
  #expect(history.count == 1)
  // The unchanged value remains inside the 0.5kg buffer → no new PR.
  let pending = try await e1rm.unacknowledgedPRs(studentId: studentID)
  #expect(pending.isEmpty)
  #expect(viewModel.pendingPRBanner == nil)
}

@MainActor
@Test func bufferSuppressesSubHalfKiloImprovements() async throws {
  let e1rm = InMemoryE1RMRepository()
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  guard let deadlift = plan.days[3].exercises.first?.exercise else {
    throw TestFailure("seed shape changed")
  }
  // Seed a baseline just under what today's prescribed set will produce:
  // 硬拉 175×3 @8.5 → RTS 0.86 → ≈203.49. Baseline 203.3 → +0.19 < 0.5 buffer.
  try await e1rm.recordPoint(
    E1RMHistoryPoint(
      id: UUID(), studentId: studentID, exerciseId: deadlift.id, setLogId: UUID(),
      computedAt: Date().addingTimeInterval(-86_400),
      e1RMKg: 203.3, sourceWeightKg: 172.5, sourceReps: 3, sourceRPE: 8.5
    ))

  let (viewModel, _) = try await makeLoadedViewModel(e1rm: e1rm)
  await viewModel.toggleComplete(rowIndex: 0)

  let history = try await e1rm.fetchHistory(studentId: studentID, exerciseId: deadlift.id)
  #expect(history.count == 2, "point still recorded")
  #expect(viewModel.pendingPRBanner == nil, "sub-buffer improvement must not fire a PR")
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
  // second identical-e1RM set must not break the 0.5kg buffer.
  let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)
  let e1rm = InMemoryE1RMRepository()
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: e1rm,
    now: { frozenNow }
  )
  await viewModel.load(date: Date(), studentID: studentID)

  await viewModel.toggleComplete(rowIndex: 0)
  await viewModel.acknowledgePendingPR()
  await viewModel.toggleComplete(rowIndex: 1)  // same prescription, same instant

  #expect(viewModel.pendingPRBanner == nil, "identical e1RM at the same instant is not a PR")
  let pending = try await e1rm.unacknowledgedPRs(studentId: studentID)
  #expect(pending.isEmpty)
}
