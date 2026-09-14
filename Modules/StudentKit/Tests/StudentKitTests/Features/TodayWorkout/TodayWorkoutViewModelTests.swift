// swiftlint:disable file_length
import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

struct TodayWorkoutLocalDayCase: Sendable, CustomTestStringConvertible {
  let identifier: String
  let year: Int
  let month: Int
  let day: Int
  let context: String

  var testDescription: String { "\(identifier)-\(context)" }
}

private let todayWorkoutLocalDayCases = [
  TodayWorkoutLocalDayCase(
    identifier: "Asia/Shanghai", year: 2030, month: 8, day: 18, context: "all-hours"),
  TodayWorkoutLocalDayCase(
    identifier: "Europe/London", year: 2030, month: 1, day: 15, context: "GMT"),
  TodayWorkoutLocalDayCase(
    identifier: "Europe/London", year: 2030, month: 7, day: 15, context: "BST"),
  TodayWorkoutLocalDayCase(
    identifier: "Europe/London", year: 2030, month: 3, day: 31, context: "DST-start"),
  TodayWorkoutLocalDayCase(
    identifier: "Europe/London", year: 2030, month: 10, day: 27, context: "DST-end"),
  TodayWorkoutLocalDayCase(
    identifier: "America/New_York", year: 2030, month: 1, day: 15, context: "standard"),
  TodayWorkoutLocalDayCase(
    identifier: "America/New_York", year: 2030, month: 7, day: 15, context: "daylight"),
  TodayWorkoutLocalDayCase(
    identifier: "America/New_York", year: 2030, month: 3, day: 10, context: "DST-start"),
  TodayWorkoutLocalDayCase(
    identifier: "America/New_York", year: 2030, month: 11, day: 3, context: "DST-end"),
]

@MainActor
@Test(arguments: todayWorkoutLocalDayCases)
func todayWorkoutMatchesTheDeviceDateOnlyValueAcrossTheEntireLocalDay(
  localDayCase: TodayWorkoutLocalDayCase
) async throws {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: localDayCase.identifier))

  let localDayStart = try #require(
    calendar.date(
      from: DateComponents(
        year: localDayCase.year,
        month: localDayCase.month,
        day: localDayCase.day
      )
    )
  )
  let nextLocalDayStart = try #require(
    calendar.date(byAdding: .day, value: 1, to: localDayStart)
  )
  let plan = StudentDemoSeed.makePlanView(
    today: localDayStart,
    todayOffset: 0,
    selectedCalendar: calendar
  )
  let expectedDay = try #require(plan.days.first)
  var samples = stride(
    from: localDayStart,
    to: nextLocalDayStart,
    by: 3_600
  ).map { $0 }
  samples.append(nextLocalDayStart.addingTimeInterval(-1))

  for selectedDate in samples {
    let viewModel = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(),
      calendar: calendar
    )

    await viewModel.load(
      date: selectedDate,
      studentID: StudentDemoSeed.studentID,
      preloadedPlan: plan
    )

    guard case .loaded(let day, _) = viewModel.state else {
      var style = Date.FormatStyle.dateTime.year().month().day().hour().minute().second()
      style.timeZone = calendar.timeZone
      let localTime = selectedDate.formatted(style)
      Issue.record("Expected plan day in \(localDayCase.identifier) at \(localTime)")
      continue
    }
    #expect(day.id == expectedDay.id)
  }
}

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
@Test func todayWorkoutDistinguishesMissingPlanFromRestDay() async {
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(date: Date(), studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .noPlan)
}

@MainActor
@Test func todayWorkoutRendersHandedOffPlanWhileRefreshingProjection() async throws {
  let studentID = StudentDemoSeed.studentID
  let now = try Date("2026-01-20T12:00:00Z", strategy: .iso8601)
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
  let plan = StudentDemoSeed.makePlanView(today: now, selectedCalendar: calendar)
  let plans = GatedStudentPlanRepository(plan: plan)
  let logs = SnapshotCountingTrainingLogRepository()
  let e1rm = SnapshotCountingE1RMRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: logs,
    e1rm: e1rm,
    calendar: calendar,
    now: { now }
  )

  let loadTask = Task {
    await viewModel.load(
      date: plan.days[0].date,
      studentID: studentID,
      preloadedPlan: plan
    )
  }
  await plans.waitUntilFetchStarted()
  for _ in 0..<100 {
    if case .loaded = viewModel.state { break }
    await Task.yield()
  }

  let renderedDayID: UUID?
  if case .loaded(let day, _) = viewModel.state {
    renderedDayID = day.id
  } else {
    renderedDayID = nil
  }
  #expect(await plans.fetchCallCount == 1)
  #expect(renderedDayID == plan.days[0].id)

  await plans.open()
  await loadTask.value

  let fetchedRanges = await logs.fetchedRanges
  let historyRange = TodayWorkoutViewModel.lastWeightHistoryRange(before: plan.days[0].date)
  // Published Jan 13, recommended Jan 17–24: the plan window includes
  // quick-log dates from publication, with one day of padding on each end.
  let lowerBound = try Date("2026-01-12T00:00:00Z", strategy: .iso8601)
  let upperBound = try Date("2026-01-25T00:00:00Z", strategy: .iso8601)
  let expectedPlanRange = lowerBound...upperBound
  #expect(fetchedRanges.count == 2)
  #expect(fetchedRanges.filter { $0 == historyRange }.count == 1)
  #expect(fetchedRanges.filter { $0 == expectedPlanRange }.count == 1)
  #expect(
    await e1rm.historyFetchCallCount
      == Set(plan.days[0].exercises.map(\.exercise.id)).count
  )
}

@MainActor
@Test func todayWorkoutAppliesRefreshedPlanWhenItDiffersFromHandoff() async {
  let studentID = StudentDemoSeed.studentID
  let handedOffPlan = StudentDemoSeed.makePlanView()
  let refreshedDay = handedOffPlan.days[0].replacingCompletion(
    completedAt: handedOffPlan.days[0].date,
    source: "auto"
  )
  let refreshedPlan = StudentPlanView(
    cycleID: handedOffPlan.cycleID,
    weekIndex: handedOffPlan.weekIndex,
    startDate: handedOffPlan.startDate,
    endDate: handedOffPlan.endDate,
    planKind: handedOffPlan.planKind,
    totalShiftDays: handedOffPlan.totalShiftDays,
    latestShiftCreatedAt: handedOffPlan.latestShiftCreatedAt,
    days: [refreshedDay] + handedOffPlan.days.dropFirst()
  )
  let plans = GatedStudentPlanRepository(plan: refreshedPlan)
  await plans.open()
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(
    date: handedOffPlan.days[0].date,
    studentID: studentID,
    preloadedPlan: handedOffPlan
  )

  guard case .loaded(let day, _) = viewModel.state else {
    Issue.record("Expected refreshed plan content to be loaded")
    return
  }
  #expect(await plans.fetchCallCount == 1)
  #expect(day.completedAt == refreshedDay.completedAt)
}

@MainActor
@Test func todayWorkoutKeepsHandedOffPlanWhenRefreshFails() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let viewModel = TodayWorkoutViewModel(
    plans: ThrowingStudentPlanRepository { TestError() },
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(
    date: plan.days[0].date,
    studentID: studentID,
    preloadedPlan: plan
  )

  guard case .loaded(let day, _) = viewModel.state else {
    Issue.record("Expected handed-off plan to remain visible after refresh failure")
    return
  }
  #expect(day.id == plan.days[0].id)
}

@MainActor
@Test func selectingAnotherSequenceDayReusesThePlanLogSnapshot() async throws {
  let studentID = StudentDemoSeed.studentID
  let now = try Date("2026-01-20T12:00:00Z", strategy: .iso8601)
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
  let plan = StudentDemoSeed.makePlanView(today: now, selectedCalendar: calendar)
  let logs = SnapshotCountingTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    logs: logs,
    calendar: calendar,
    now: { now }
  )

  await viewModel.load(dayID: plan.days[0].id, studentID: studentID)
  await viewModel.load(dayID: plan.days[1].id, studentID: studentID)

  // Switching sequence days reuses the same publication-inclusive snapshot.
  let lowerBound = try Date("2026-01-12T00:00:00Z", strategy: .iso8601)
  let upperBound = try Date("2026-01-25T00:00:00Z", strategy: .iso8601)
  let expectedPlanRange = lowerBound...upperBound
  #expect(await logs.fetchedRanges.filter { $0 == expectedPlanRange }.count == 1)
  guard case .loaded(let selectedDay, _) = viewModel.state else {
    Issue.record("Expected selected sequence day")
    return
  }
  #expect(selectedDay.id == plan.days[1].id)
}

@MainActor
@Test func invalidSelectedDayFallsBackToSequenceCursor() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let expectedCursor = try #require(StudentPlanSequence.cursorDay(in: plan))
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(dayID: UUID(), studentID: studentID)

  guard case .loaded(let selectedDay, _) = viewModel.state else {
    Issue.record("Expected cursor workout instead of a rest state")
    return
  }
  #expect(selectedDay.id == expectedCursor.id)
}

@MainActor
@Test func completionMutationsFetchAndPropagateOneProjectionEach() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let cursorID = try #require(StudentPlanSequence.cursorDay(in: plan)?.id)
  let plans = CompletionProjectionCountingRepository(plan: plan)
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: cursorID, studentID: studentID)

  #expect(await viewModel.completeCurrentDay())
  #expect(await plans.refreshCount == 1)
  #expect(viewModel.planProjection?.days.first { $0.id == cursorID }?.completedAt != nil)

  #expect(await viewModel.undoCurrentDayCompletion())
  #expect(await plans.refreshCount == 2)
  #expect(viewModel.planProjection?.days.first { $0.id == cursorID }?.completedAt == nil)
  #expect(viewModel.completionRevision == 2)
}

private actor CompletionProjectionCountingRepository: StudentPlanRepository {
  private var plan: StudentPlanView
  private(set) var refreshCount = 0

  init(plan: StudentPlanView) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    plan
  }

  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    refreshCount += 1
    return plan
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    plan.days
  }

  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    let completedAt = Date(timeIntervalSince1970: 2_000_000_000)
    replaceDay(id: id, completedAt: completedAt, source: "manual")
    return PlanDayCompletion(
      id: UUID(),
      dayID: id,
      studentID: studentID,
      source: "manual",
      completedAt: completedAt
    )
  }

  func undoDayCompletion(id: UUID, studentID: UUID) async throws {
    replaceDay(id: id, completedAt: nil, source: nil)
  }

  private func replaceDay(id: UUID, completedAt: Date?, source: String?) {
    plan = StudentPlanView(
      cycleID: plan.cycleID,
      weekIndex: plan.weekIndex,
      startDate: plan.startDate,
      endDate: plan.endDate,
      planKind: plan.planKind,
      publishedAt: plan.publishedAt,
      totalShiftDays: plan.totalShiftDays,
      latestShiftCreatedAt: plan.latestShiftCreatedAt,
      days: plan.days.map { day in
        day.id == id
          ? day.replacingCompletion(completedAt: completedAt, source: source)
          : day
      }
    )
  }
}

private actor GatedStudentPlanRepository: StudentPlanRepository {
  private let plan: StudentPlanView?
  private var isOpen = false
  private var fetchStarted = false
  private var gateWaiters: [CheckedContinuation<Void, Never>] = []
  private var fetchStartWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var fetchCallCount = 0

  init(plan: StudentPlanView?) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    fetchCallCount += 1
    fetchStarted = true
    for waiter in fetchStartWaiters { waiter.resume() }
    fetchStartWaiters = []
    if !isOpen {
      await withCheckedContinuation { gateWaiters.append($0) }
    }
    return plan
  }

  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    plan?.days.first { $0.date == date }
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    plan?.days ?? []
  }

  func waitUntilFetchStarted() async {
    if fetchStarted { return }
    await withCheckedContinuation { fetchStartWaiters.append($0) }
  }

  func open() {
    isOpen = true
    for waiter in gateWaiters { waiter.resume() }
    gateWaiters = []
  }
}

private actor SnapshotCountingTrainingLogRepository: StudentTrainingLogRepository {
  private(set) var fetchedRanges: [ClosedRange<Date>] = []

  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    log
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    fetchedRanges.append(dateRange)
    return []
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}

private actor SnapshotCountingE1RMRepository: E1RMRepository {
  private(set) var historyFetchCallCount = 0

  func recordPoint(_ point: E1RMHistoryPoint) async throws {}

  func upsertPoint(_ point: E1RMHistoryPoint) async throws -> E1RMHistoryPoint {
    point
  }

  func updatePointConfidence(
    studentId: UUID,
    pointIDs: Set<UUID>,
    confidence: E1RMConfidence
  ) async throws {}

  func replaceHistory(
    studentId: UUID,
    with points: [E1RMHistoryPoint],
    weightBaselines: [E1RMWeightBaseline],
    prEvents: [PRBreakthroughEvent]
  ) async throws {}

  func historySnapshot(
    studentId: UUID,
    exerciseIds: [UUID]
  ) async throws -> E1RMHistorySnapshot {
    E1RMHistorySnapshot(history: [:], revision: 0)
  }

  func replaceHistory(
    studentId: UUID,
    with points: [E1RMHistoryPoint],
    weightBaselines: [E1RMWeightBaseline],
    prEvents: [PRBreakthroughEvent],
    ifUnchangedSince revision: UInt64
  ) async throws -> Bool {
    true
  }

  func fetchHistory(
    studentId: UUID,
    exerciseId: UUID
  ) async throws -> [E1RMHistoryPoint] {
    historyFetchCallCount += 1
    return []
  }

  func fetchHistory(
    studentId: UUID,
    exerciseIds: [UUID]
  ) async throws -> [UUID: [E1RMHistoryPoint]] {
    [:]
  }

  func fetchHistory(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [E1RMHistoryPoint] {
    []
  }

  func maxBefore(
    studentId: UUID,
    exerciseId: UUID,
    before: Date,
    excludingSetLogId: UUID?
  ) async throws -> Double? {
    nil
  }

  func recordWeightBaseline(
    _ candidate: E1RMWeightBaseline
  ) async throws -> E1RMWeightBaseline? {
    nil
  }

  func fetchWeightBaseline(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> E1RMWeightBaseline? {
    nil
  }

  func fetchWeightBaselines(studentId: UUID) async throws -> [E1RMWeightBaseline] {
    []
  }

  func recordPR(_ event: PRBreakthroughEvent) async throws {}

  func recordPRIfAbsent(
    _ event: PRBreakthroughEvent,
    forSetLogId setLogId: UUID
  ) async throws -> Bool {
    true
  }

  func fetchPRs(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [PRBreakthroughEvent] {
    []
  }

  func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent] {
    []
  }

  func acknowledgePR(eventId: UUID) async throws {}

  func prEvents(studentId: UUID, since: Date) async throws -> [PRBreakthroughEvent] {
    []
  }
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
    now: { plan.days[0].date.addingTimeInterval(12 * 3_600) }
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
    now: { plan.days[0].date.addingTimeInterval(12 * 3_600) }
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
  #expect(recordedLogs[0].setIndex == 0)
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
    now: { plan.days[0].date.addingTimeInterval(12 * 3_600) }
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
    now: { plan.days[0].date.addingTimeInterval(12 * 3_600) }
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

// P0 2026-08-20: sequence progression lets real training run past the plan's
// scheduled calendar. Logs recorded after the scheduled end must still bind to
// the day's drafts — a schedule-clamped fetch window made them vanish.
@MainActor
@Test func todayWorkoutKeepsLogsRecordedAfterScheduledPlanEnd() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let lastScheduled = try #require(plan.days.map(\.scheduledDate).max())
  let now = lastScheduled.addingTimeInterval(30 * 86_400)
  let day = plan.days[0]
  let exercise = try #require(day.exercises.first)
  let prescribed = try #require(exercise.prescribedSets.first)
  let lateLog = StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: exercise.id,
    setIndex: prescribed.setIndex,
    loggedAt: now.addingTimeInterval(-3_600),
    weightKg: 123.5,
    reps: 5,
    completed: true
  )
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(seed: [lateLog]),
    now: { now }
  )

  await viewModel.load(dayID: day.id, studentID: studentID)

  guard case .loaded(_, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  let draft = try #require(
    drafts.first {
      $0.planExerciseID == exercise.id && $0.prescribed.setIndex == prescribed.setIndex
    }
  )
  #expect(draft.completed)
  #expect(draft.actualWeight == 123.5)
  #expect(draft.loggedSetID == lateLog.id)
}
