import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Suite struct TodayWorkoutQuickLogTests {
  @Test func unrecordedAccessoryQuickLogPreservesPrescribedAndFallbackRPE() async throws {
    let studentID = StudentDemoSeed.studentID
    let exercise = Exercise(
      id: UUID(), name: "Row", exerciseType: .accessory, isCompetitionLift: false,
      muscleGroups: [], equipment: [], createdAt: quickLogNow)
    let planExercise = StudentPlanExercise(
      id: UUID(), exercise: exercise, sequenceIndex: 0,
      prescribedSets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: 60, reps: 12, rpe: 7),
        PrescribedSet(id: UUID(), setIndex: 1, weightKg: 60, reps: 12),
      ])
    let day = StudentPlanDay(id: UUID(), date: quickLogNow, exercises: [planExercise])
    let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: quickLogNow, days: [day])
    let logs = InMemoryStudentTrainingLogRepository()
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
      logs: logs, now: { quickLogNow })
    await model.load(dayID: day.id, studentID: studentID)
    let drafts = try #require(model.currentDrafts)
    #expect(drafts.allSatisfy { $0.loggedSetID == nil && !$0.completed })
    let quickLog = makeQuickLogTestPlan(drafts: drafts)
    #expect(quickLog.rows.map(\.draft.actualRPE) == [7, 8])
    #expect(await model.quickLog(plan: quickLog) == .completed)
    let stored = try await logs.fetchLogsForExercise(
      studentID: studentID, planExerciseID: planExercise.id)
    #expect(stored.sorted { $0.setIndex < $1.setIndex }.map(\.rpe) == [7, 8])
  }

  @Test func prescribedQuickLogRecordsEverySetCompletesDayAndRecordsE1RM() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let e1rm = InMemoryE1RMRepository()
    let fixture = try await makeQuickLogFixture(logs: logs, e1rm: e1rm)
    let selectedDate = quickLogNow.addingTimeInterval(-86_400)
    let plan = makeQuickLogTestPlan(drafts: fixture.drafts, selectedDate: selectedDate)

    let outcome = await fixture.viewModel.quickLog(plan: plan)

    #expect(outcome == .completed)
    let stored = try await logs.fetchLogs(
      studentID: fixture.studentID,
      in: Date.distantPast...Date.distantFuture
    )
    #expect(stored.count == fixture.drafts.count)
    #expect(stored.allSatisfy { !$0.assumed })
    #expect(stored.allSatisfy { $0.loggedAt == quickLogLocalNoon(for: selectedDate) })
    let completedPlan = await fixture.store.getPublishedProjection(forStudent: fixture.studentID)
    #expect(completedPlan?.days.first(where: { $0.id == fixture.day.id })?.completedAt != nil)
    let firstDraft = try #require(fixture.drafts.first)
    let history = try await e1rm.fetchHistory(
      studentId: fixture.studentID,
      exerciseId: firstDraft.exerciseID
    )
    #expect(!history.isEmpty)
    #expect(history.allSatisfy { $0.computedAt == quickLogLocalNoon(for: selectedDate) })
  }

  @Test func exclusionsWriteOnlyIncludedPrescriptionSlots() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await makeQuickLogFixture(logs: logs, dayOffset: 3)
    let grouped = Dictionary(grouping: fixture.drafts, by: \.planExerciseID)
    let groups = grouped.values.sorted {
      ($0.first?.planExerciseSortOrder ?? 0) < ($1.first?.planExerciseSortOrder ?? 0)
    }
    let firstExercise = try #require(groups.first)
    let secondExercise = try #require(groups.dropFirst().first)
    var plan = makeQuickLogTestPlan(drafts: fixture.drafts)
    for draft in firstExercise {
      plan.setIncluded(false, for: draft.id)
    }
    let excludedTail = try #require(
      secondExercise.max(by: { $0.prescribed.setIndex < $1.prescribed.setIndex }))
    plan.setIncluded(false, for: excludedTail.id)

    let outcome = await fixture.viewModel.quickLog(plan: plan)

    #expect(outcome == .completed)
    let stored = try await logs.fetchLogs(
      studentID: fixture.studentID,
      in: Date.distantPast...Date.distantFuture
    )
    #expect(!stored.contains { $0.planExerciseID == firstExercise[0].planExerciseID })
    let secondIndexes =
      stored
      .filter { $0.planExerciseID == secondExercise[0].planExerciseID }
      .map(\.setIndex)
      .sorted()
    #expect(secondIndexes == secondExercise.dropLast().map(\.prescribed.setIndex))
  }

  @Test func excludingEverySetRejectsWithoutWritingOrCompleting() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await makeQuickLogFixture(logs: logs)
    var plan = makeQuickLogTestPlan(drafts: fixture.drafts)
    for draft in fixture.drafts {
      plan.setIncluded(false, for: draft.id)
    }

    let outcome = await fixture.viewModel.quickLog(plan: plan)

    #expect(outcome == .noIncludedSets)
    let stored = try await logs.fetchLogs(
      studentID: fixture.studentID,
      in: Date.distantPast...Date.distantFuture
    )
    #expect(stored.isEmpty)
    let unchangedPlan = await fixture.store.getPublishedProjection(forStudent: fixture.studentID)
    #expect(unchangedPlan?.days.first(where: { $0.id == fixture.day.id })?.completedAt == nil)
  }

  @Test func recordFailureKeepsPrefixAndRetryContinuesAtFailedSet() async throws {
    let logs = FailOnceTrainingLogRepository(failingAttempt: 3)
    let fixture = try await makeQuickLogFixture(logs: logs)
    let plan = makeQuickLogTestPlan(drafts: fixture.drafts)

    let firstOutcome = await fixture.viewModel.quickLog(plan: plan)

    #expect(firstOutcome == .partialFailure(writtenCount: 2, failedIndex: 2))
    #expect(await logs.storedLogs().count == 2)
    let afterFailure = await fixture.store.getPublishedProjection(forStudent: fixture.studentID)
    #expect(afterFailure?.days.first(where: { $0.id == fixture.day.id })?.completedAt == nil)

    let retryOutcome = await fixture.viewModel.quickLog(plan: plan)

    #expect(retryOutcome == .completed)
    #expect(await logs.storedLogs().count == fixture.drafts.count)
    #expect(await logs.attemptedSlots().count == fixture.drafts.count + 1)
    let completed = await fixture.store.getPublishedProjection(forStudent: fixture.studentID)
    #expect(completed?.days.first(where: { $0.id == fixture.day.id })?.completedAt != nil)
  }

  @Test func partialFailureWritesSuccessfulSetsBackIntoDrafts() async throws {
    let logs = FailOnceTrainingLogRepository(failingAttempt: 2)
    let fixture = try await makeQuickLogFixture(logs: logs)
    let plan = makeQuickLogTestPlan(drafts: fixture.drafts)

    _ = await fixture.viewModel.quickLog(plan: plan)

    let drafts = try #require(fixture.viewModel.currentDrafts)
    #expect(drafts[0].completed, "the written set must show as recorded")
    #expect(drafts[0].loggedSetID != nil)
    #expect(!drafts[1].completed, "the failed set stays unrecorded")
  }

  @Test func completionFailureKeepsWrittenSetsAndReturnsSeparateOutcome() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let base = StudentDemoSeed.makePlanView(today: quickLogNow, todayOffset: 2)
    let plans = CompletionFailingPlanRepository(plan: base)
    let e1rm = InMemoryE1RMRepository()
    let viewModel = TodayWorkoutViewModel(
      plans: plans,
      logs: logs,
      e1rm: e1rm,
      now: { quickLogNow }
    )
    let studentID = StudentDemoSeed.studentID
    await viewModel.load(date: quickLogNow, studentID: studentID)
    guard case .loaded(_, let drafts) = viewModel.state else {
      throw QuickLogTestFailure("expected loaded state")
    }

    let outcome = await viewModel.quickLog(plan: makeQuickLogTestPlan(drafts: drafts))

    #expect(outcome == .completionFailed)
    let stored = try await logs.fetchLogs(
      studentID: studentID,
      in: Date.distantPast...Date.distantFuture
    )
    #expect(stored.count == drafts.count)
    #expect(await plans.completionCallCount() == 1)
  }
}
