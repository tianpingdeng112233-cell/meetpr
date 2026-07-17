import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func studentSessionSummaryAggregatesCompletedSetsOnly() {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: 100, reps: 5, repsMax: nil, rpe: 8)
  func draft(
    weight: Decimal, reps: Int, rpe: Decimal, completed: Bool
  ) -> TodayWorkoutViewModel.SetRowDraft {
    TodayWorkoutViewModel.SetRowDraft(
      id: UUID(), planExerciseID: UUID(), exerciseID: UUID(), exerciseName: "深蹲",
      isAccessory: false,
      prescribed: prescribed, actualWeight: weight, actualReps: reps,
      actualRPE: rpe, completed: completed)
  }

  let summary = StudentSessionSummary(drafts: [
    draft(weight: 100, reps: 5, rpe: 8, completed: true),
    draft(weight: 120, reps: 3, rpe: 9, completed: true),
    draft(weight: 100, reps: 5, rpe: 7, completed: false),
  ])

  #expect(summary.completedSets == 2)
  #expect(summary.totalReps == 8)
  #expect(summary.totalVolumeKg == 860)  // 100*5 + 120*3
  #expect(summary.averageRPE == 8.5)  // (8 + 9) / 2
}

@Test func studentFormattingResultOmitsMissingWeightAndRPE() {
  #expect(StudentFormatting.result(weightKg: 142.5, reps: 5, rpe: 7.5) == "142.5kg × 5 @ RPE 7.5")
  #expect(StudentFormatting.result(weightKg: nil, reps: 5, rpe: 8) == "5 @ RPE 8")
  #expect(StudentFormatting.result(weightKg: 100, reps: 5, rpe: nil) == "100kg × 5")
}

@MainActor
@Test func studentSessionSummaryReportsTopSetPerExercise() {
  let squatID = UUID()
  func draft(
    setIndex: Int, weight: Decimal, reps: Int, rpe: Decimal, completed: Bool
  ) -> TodayWorkoutViewModel.SetRowDraft {
    TodayWorkoutViewModel.SetRowDraft(
      id: UUID(), planExerciseID: squatID, exerciseID: UUID(), exerciseName: "深蹲",
      isAccessory: false,
      prescribed: PrescribedSet(
        id: UUID(), setIndex: setIndex, weightKg: weight, reps: reps, repsMax: nil, rpe: rpe),
      actualWeight: weight, actualReps: reps, actualRPE: rpe, completed: completed)
  }

  let summary = StudentSessionSummary(drafts: [
    draft(setIndex: 0, weight: 100, reps: 5, rpe: 7, completed: true),
    draft(setIndex: 1, weight: 142.5, reps: 5, rpe: 8, completed: true),  // top set
    draft(setIndex: 2, weight: 150, reps: 5, rpe: 9, completed: false),  // heavier but not done
  ])

  #expect(summary.exercises.count == 1)
  let squat = summary.exercises.first
  #expect(squat?.name == "深蹲")
  #expect(squat?.topSetWeightKg == 142.5)
  #expect(squat?.topSetReps == 5)
  #expect(squat?.topSetRPE == 8)
}

@Test func makeHistoricalLogsSeedsNoFutureLogs() {
  let startOfTomorrow = Calendar(identifier: .gregorian)
    .startOfDay(for: Date())
    .addingTimeInterval(86_400)
  let logs = StudentDemoSeed.makeHistoricalLogs()
  #expect(!logs.isEmpty)
  #expect(logs.allSatisfy { $0.loggedAt < startOfTomorrow })
}

@MainActor
@Test func todayWorkoutViewModelPersistsEditsToCompletedSet() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: logs,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  // Complete the set, then edit the already-completed set and re-save.
  await viewModel.commitSet(rowIndex: 0)
  viewModel.updateReps(rowIndex: 0, reps: 7)
  await viewModel.commitSet(rowIndex: 0)

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  guard case .loaded(_, let reloaded) = viewModel.state else {
    Issue.record("Expected loaded state after reload")
    return
  }
  #expect(reloaded[0].completed)
  #expect(reloaded[0].actualReps == 7)
}

@MainActor
@Test func todayWorkoutViewModelLoadsRecordsAndReturnsToLoaded() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: logs,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )

  #expect(viewModel.state == .idle)
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  guard case .loaded(let day, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(day == plan.days[0])
  #expect(drafts.count == 3)

  viewModel.updateReps(rowIndex: 0, reps: 4)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .loaded(_, let recordedDrafts) = viewModel.state else {
    Issue.record("Expected loaded state after recording")
    return
  }
  #expect(recordedDrafts[0].completed)

  let recordedLogs = try await logs.fetchLogsForExercise(
    studentID: studentID,
    planExerciseID: recordedDrafts[0].planExerciseID
  )
  #expect(recordedLogs.count == 1)
  #expect(recordedLogs[0].reps == 4)

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  guard case .loaded(_, let reloadedDrafts) = viewModel.state else {
    Issue.record("Expected loaded state after reload")
    return
  }
  #expect(reloadedDrafts[0].completed)
  #expect(reloadedDrafts[0].actualReps == 4)
}

@MainActor
@Test func todayWorkoutViewModelUpdatesActualWeight() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: logs,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  viewModel.updateWeight(rowIndex: 0, weight: 142.5)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .loaded(_, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(drafts[0].actualWeight == 142.5)

  let recordedLogs = try await logs.fetchLogsForExercise(
    studentID: studentID,
    planExerciseID: drafts[0].planExerciseID
  )
  #expect(recordedLogs[0].weightKg == 142.5)
}

@MainActor
@Test func todayWorkoutViewModelKeepsWorkoutAndDraftWhenRecordingFails() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  viewModel.updateWeight(rowIndex: 0, weight: 142.5)
  let saved = await viewModel.commitSet(rowIndex: 0)

  guard case .loaded(_, let drafts) = viewModel.state else {
    Issue.record("Expected loaded workout to remain visible")
    return
  }
  #expect(!saved)
  #expect(drafts[0].actualWeight == 142.5)
  #expect(!drafts[0].completed)
  #expect(viewModel.actionErrorMessage == "记录没有保存，请重试。你的输入仍保留在本页。")
}

@MainActor
@Test func todayWorkoutViewModelExplainsServerRecordingFailure() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: ServerFailingTrainingLogRepository()
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  let setLogID = await viewModel.ensureLoggedSetID(rowIndex: 0)

  #expect(setLogID == nil)
  guard case .loaded = viewModel.state else {
    Issue.record("Expected loaded workout to remain visible")
    return
  }
  #expect(
    viewModel.actionErrorMessage
      == "服务器暂时无法保存（500），请稍后重试。你的输入仍保留在本页。")
}

private actor ServerFailingTrainingLogRepository: StudentTrainingLogRepository {
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    throw APIError.httpStatus(500, Data(#"{"error":"internal_error"}"#.utf8))
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}

@MainActor
@Test func todayWorkoutViewModelRestoresLoadedWhenRecordingURLCancelled() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: ThrowingTrainingLogRepository { URLError(.cancelled) }
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .loaded = viewModel.state else {
    Issue.record("Expected loaded state restored, got \(viewModel.state)")
    return
  }
  #expect(viewModel.actionErrorMessage == nil)
}

@MainActor
@Test func todayWorkoutViewModelRestoresLoadedWhenRecordingCancellationError() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: ThrowingTrainingLogRepository { CancellationError() }
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .loaded = viewModel.state else {
    Issue.record("Expected loaded state restored, got \(viewModel.state)")
    return
  }
  #expect(viewModel.actionErrorMessage == nil)
}

@MainActor
@Test func todayWorkoutViewModelMapsExpiredSessionDuringLoadToLoginMessage() async {
  let viewModel = TodayWorkoutViewModel(
    plans: ThrowingStudentPlanRepository { SessionStateReaderError.authenticationExpired },
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(date: Date(), studentID: UUID())

  #expect(viewModel.state == .error("登录已过期，请重新登录"))
}

@MainActor
@Test func todayWorkoutViewModelMapsGenericLoadFailureToRetryMessage() async {
  let viewModel = TodayWorkoutViewModel(
    plans: ThrowingStudentPlanRepository { APIError.httpStatus(500, Data()) },
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(date: Date(), studentID: UUID())

  #expect(viewModel.state == .error("操作失败，请稍后重试"))
}

@MainActor
@Test func todayWorkoutViewModelMapsExpiredSessionDuringSaveToLoginMessage() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: ThrowingTrainingLogRepository { SessionStateReaderError.authenticationExpired }
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  await viewModel.toggleComplete(rowIndex: 0)

  #expect(viewModel.actionErrorMessage == "登录已过期，请重新登录")
}

@MainActor
@Test func ensureLoggedSetIDKeepsFlushedEditsWithoutCompleting() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  // Video-before-complete flow (beta 2026-07-11): the entry sheet flushes the
  // typed numbers, then mints a set-log id for the attachment. The minted log
  // must carry the flushed values, stay incomplete, and survive the rebuild.
  viewModel.updateWeight(rowIndex: 0, weight: 100)
  viewModel.updateReps(rowIndex: 0, reps: 4)
  viewModel.updateRPE(rowIndex: 0, rpe: 9)
  let setLogID = await viewModel.ensureLoggedSetID(rowIndex: 0)

  #expect(setLogID != nil)
  guard case .loaded(_, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state after ensureLoggedSetID")
    return
  }
  #expect(drafts[0].actualWeight == 100)
  #expect(drafts[0].actualReps == 4)
  #expect(drafts[0].actualRPE == 9)
  #expect(!drafts[0].completed)
  #expect(drafts[0].loggedSetID == setLogID)
}
