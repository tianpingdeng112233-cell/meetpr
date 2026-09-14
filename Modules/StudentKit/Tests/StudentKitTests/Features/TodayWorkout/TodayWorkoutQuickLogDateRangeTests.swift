import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct TodayWorkoutQuickLogDateRangeTests {
  @Test func coldLoadKeepsQuickLogsFromPublicationBeforeTheRecommendedStart() async throws {
    let fixture = try await makeEarlyQuickLogFixture()
    let reloaded = TodayWorkoutViewModel(
      plans: fixture.plans,
      logs: fixture.logs,
      e1rm: InMemoryE1RMRepository(),
      calendar: quickLogUTCCalendar,
      now: { quickLogNow }
    )

    await reloaded.load(dayID: fixture.day.id, studentID: StudentDemoSeed.studentID)

    let drafts = try #require(reloaded.currentDrafts)
    #expect(drafts.count == fixture.setCount)
    #expect(drafts.allSatisfy { $0.completed && $0.loggedSetID != nil })
  }

  @Test func weekOverviewKeepsQuickLogsFromPublicationBeforeTheRecommendedStart() async throws {
    let fixture = try await makeEarlyQuickLogFixture()
    let overview = WeekOverviewViewModel(
      plans: fixture.plans,
      logs: fixture.logs,
      now: { quickLogNow }
    )

    await overview.load(studentID: StudentDemoSeed.studentID)

    guard case .loaded(_, let loadedLogs, _) = overview.state else {
      Issue.record("Expected loaded week overview")
      return
    }
    #expect(loadedLogs.count == fixture.setCount)

    await overview.refreshLogs(studentID: StudentDemoSeed.studentID)

    guard case .loaded(_, let refreshedLogs, _) = overview.state else {
      Issue.record("Expected loaded week overview after refresh")
      return
    }
    #expect(refreshedLogs.count == fixture.setCount)
  }
}

private struct EarlyQuickLogFixture {
  let day: StudentPlanDay
  let setCount: Int
  let plans: InMemoryStudentPlanRepository
  let logs: InMemoryStudentTrainingLogRepository
}

@MainActor
private func makeEarlyQuickLogFixture() async throws -> EarlyQuickLogFixture {
  let seed = StudentDemoSeed.makePlanView(today: quickLogNow, todayOffset: 2)
  let publishedAt = quickLogNow.addingTimeInterval(-7 * 86_400)
  let recommendedDate = quickLogNow.addingTimeInterval(7 * 86_400)
  let day = StudentPlanDay(
    id: UUID(),
    date: recommendedDate,
    exercises: seed.days[2].exercises
  )
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: recommendedDate,
    publishedAt: publishedAt,
    days: [day]
  )
  let plans = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan]),
    now: { quickLogNow }
  )
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: logs,
    e1rm: InMemoryE1RMRepository(),
    calendar: quickLogUTCCalendar,
    now: { quickLogNow }
  )
  await viewModel.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  var quickLog = try #require(viewModel.makeQuickLogPlan())
  quickLog.selectDate(publishedAt)
  #expect(quickLog.selectedDate == quickLogUTCCalendar.startOfDay(for: publishedAt))
  #expect(await viewModel.quickLog(plan: quickLog) == .completed)
  return EarlyQuickLogFixture(
    day: day,
    setCount: quickLog.includedSetCount,
    plans: plans,
    logs: logs
  )
}
