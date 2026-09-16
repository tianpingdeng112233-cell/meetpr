import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Suite struct TodayWorkoutQuickLogRetryTests {
  @Test func changingTheDateAfterPartialFailureRewritesEverySetOnTheNewDate() async throws {
    let logs = FailOnceTrainingLogRepository(failingAttempt: 2)
    let fixture = try await makeQuickLogFixture(logs: logs)
    let firstDate = quickLogNow.addingTimeInterval(-2 * 86_400)
    let secondDate = quickLogNow.addingTimeInterval(-86_400)

    _ = await fixture.viewModel.quickLog(
      plan: makeQuickLogTestPlan(drafts: fixture.drafts, selectedDate: firstDate)
    )
    let retry = await fixture.viewModel.quickLog(
      plan: makeQuickLogTestPlan(drafts: fixture.drafts, selectedDate: secondDate)
    )

    #expect(retry == .completed)
    let stored = await logs.storedLogs()
    #expect(stored.count == fixture.drafts.count)
    #expect(stored.allSatisfy { $0.loggedAt == quickLogLocalNoon(for: secondDate) })
  }

  @Test func freshSheetForgetsThePreviousAttempt() async throws {
    let logs = FailOnceTrainingLogRepository(failingAttempt: 2)
    let fixture = try await makeQuickLogFixture(logs: logs)
    let plan = makeQuickLogTestPlan(drafts: fixture.drafts)

    _ = await fixture.viewModel.quickLog(plan: plan)
    _ = fixture.viewModel.makeQuickLogPlan()
    let retry = await fixture.viewModel.quickLog(plan: plan)

    #expect(retry == .completed)
    // Slot 1 was written twice (idempotent upsert), slot 2 failed once then
    // succeeded, slot 3 once: attempts = drafts + 2.
    #expect(await logs.attemptedSlots().count == fixture.drafts.count + 2)
  }

  @Test func dateLowerBoundUsesThePreviousDaysTrainingDate() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let studentID = StudentDemoSeed.studentID
    let plan = StudentDemoSeed.makePlanView(today: quickLogNow, todayOffset: 2)
    // The bound comes from the completed day nearest the cursor.
    let previousDay = try #require(plan.days.last(where: { $0.completedAt != nil }))
    let previousExercise = try #require(previousDay.exercises.first)
    // Backfilled previous day: logged_date long before the write timestamp.
    _ = try await logs.recordSet(
      StudentSetLog(
        id: UUID(),
        studentID: studentID,
        planExerciseID: previousExercise.id,
        setIndex: 0,
        loggedAt: quickLogNow,
        loggedDate: "2026-01-02",
        weightKg: 100,
        reps: 5,
        completed: true
      )
    )
    let fixture = try await makeQuickLogFixture(logs: logs)

    let quickLogPlan = try #require(fixture.viewModel.makeQuickLogPlan())

    // The view model resolves training days in its own (device) calendar.
    let expected = try #require(
      Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 2)))
    #expect(quickLogPlan.allowedDateRange.lowerBound == Calendar.current.startOfDay(for: expected))
  }

  @Test func quickLogCompletesTheDayItWroteEvenIfTheCursorMovesMidFlight() async throws {
    let studentID = StudentDemoSeed.studentID
    let plan = StudentDemoSeed.makePlanView(today: quickLogNow, todayOffset: 2)
    let store = TestStudentPlanStore(seed: [studentID: plan])
    let plans = InMemoryStudentPlanRepository(store: store, now: { quickLogNow })
    let logs = HookedTrainingLogRepository()
    let viewModel = TodayWorkoutViewModel(
      plans: plans,
      logs: logs,
      e1rm: InMemoryE1RMRepository(),
      now: { quickLogNow }
    )
    let writtenDay = plan.days[2]
    let otherDay = plan.days[3]
    await viewModel.load(dayID: writtenDay.id, studentID: studentID)
    guard case .loaded(_, let drafts) = viewModel.state else {
      throw QuickLogTestFailure("expected loaded state")
    }
    // A refresh moves the selection to another day while sets are being written.
    await logs.setOnRecord {
      await viewModel.load(dayID: otherDay.id, studentID: studentID)
    }

    let outcome = await viewModel.quickLog(plan: makeQuickLogTestPlan(drafts: drafts))

    #expect(outcome == .completed)
    let projection = await store.getPublishedProjection(forStudent: studentID)
    #expect(projection?.days.first(where: { $0.id == writtenDay.id })?.completedAt != nil)
    #expect(projection?.days.first(where: { $0.id == otherDay.id })?.completedAt == nil)
    guard case .loaded(let visibleDay, let visibleDrafts) = viewModel.state else {
      throw QuickLogTestFailure("expected loaded state after the race")
    }
    #expect(visibleDay.id == otherDay.id, "the screen must stay on the day the refresh loaded")
    #expect(
      visibleDrafts.allSatisfy { draft in
        otherDay.exercises.contains { $0.id == draft.planExerciseID }
      })
  }
}
