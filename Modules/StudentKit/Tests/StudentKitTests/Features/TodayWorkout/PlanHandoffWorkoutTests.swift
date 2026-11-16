import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test(arguments: [false, true])
func handoffPreviewNeverCreatesDraftsOrWritesAndReturnUsesCursor(offline: Bool) async throws {
  let fixture = HandoffWorkoutFixture()
  let logs = InMemoryStudentTrainingLogRepository()
  let queue = try SetSyncQueue(
    studentID: StudentDemoSeed.studentID, storage: MemorySetSyncStorage()
  ) {
    .planned($0.plannedLog)
  }
  let model = TodayWorkoutViewModel(
    plans: fixture.repository, logs: logs, setSyncQueue: offline ? queue : nil)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  let drafts = model.currentDrafts
  await model.browseAdjacentPlan(forward: true)
  #expect(model.isPreviewingPlan)
  #expect(model.displayedPlan?.cycleID == fixture.upcoming.cycleID)
  #expect(model.currentDrafts == drafts)
  if let exercise = model.currentDay?.exercises.first {
    model.addExtraSet(exerciseID: exercise.id)
    model.addStudentExercise(exercise.exercise)
  }
  model.updateWeight(rowIndex: 0, weight: 999)
  #expect(await model.ensureLoggedSetID(rowIndex: 0) == nil)
  #expect(model.currentDrafts == drafts)
  #expect(queue.records.isEmpty)
  #expect(!(await model.commitSet(rowIndex: 0)))
  #expect(!(await model.completeCurrentDay()))
  #expect(await fixture.repository.completions == 0)
  let recorded = try await logs.fetchLogs(
    studentID: StudentDemoSeed.studentID, in: Date.distantPast...Date.distantFuture)
  #expect(recorded.isEmpty)
  await model.returnToCurrentPlan()
  #expect(!model.isPreviewingPlan)
  #expect(model.currentDay?.id == StudentPlanSequence.cursorDay(in: fixture.current)?.id)
}

struct HandoffWorkoutFixture {
  let current: StudentPlanView
  let upcoming: StudentPlanView
  let repository: HandoffWorkoutRepository

  init() {
    let seed = StudentDemoSeed.makePlanView()
    let nextID = UUID()
    let handoff = StudentPlanHandoff(
      currentPlanID: seed.cycleID,
      plans: [
        .init(
          id: seed.cycleID, name: "10.19 计划", weeks: 5, completedTrainingDays: 16,
          totalTrainingDays: 20, status: .current),
        .init(
          id: nextID, name: "11.23 计划", weeks: 12, completedTrainingDays: 0,
          totalTrainingDays: 36, status: .upcoming),
      ])
    var old = seed
    old.handoff = handoff
    let next = StudentPlanView(
      cycleID: nextID, handoff: handoff, weekIndex: 1,
      startDate: seed.startDate.addingTimeInterval(35 * 86400),
      days: seed.days.map {
        StudentPlanDay(
          id: UUID(), weekNumber: $0.weekNumber, dayOfWeek: $0.dayOfWeek,
          date: $0.date.addingTimeInterval(35 * 86400), exercises: $0.exercises)
      })
    current = old
    upcoming = next
    repository = HandoffWorkoutRepository(current: old, upcoming: next)
  }
}

actor HandoffWorkoutRepository: StudentPlanRepository {
  var current: StudentPlanView
  let original: StudentPlanView
  let upcoming: StudentPlanView
  var completions = 0
  var hasCurrentPlan = true
  init(current: StudentPlanView, upcoming: StudentPlanView) {
    self.current = current
    self.original = current
    self.upcoming = upcoming
  }
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    hasCurrentPlan ? current : nil
  }
  func removeCurrentPlan() { hasCurrentPlan = false }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { current.days }
  func fetchPlan(id: UUID, studentID: UUID) async throws -> StudentPlanView? {
    id == upcoming.cycleID ? upcoming : original
  }
  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    completions += 1
    return PlanDayCompletion(
      id: UUID(), dayID: id, studentID: studentID, source: "manual", completedAt: Date())
  }
}

@MainActor
@Test func handoffWaitsForEntryAndNoticeDismissalSurvivesRelaunch() async throws {
  let fixture = HandoffWorkoutFixture()
  let defaults = try #require(UserDefaults(suiteName: "handoff-\(UUID())"))
  let model = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(), effortDefaults: defaults)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  let originalDay = model.currentDay?.id
  await fixture.repository.advance()
  await model.refreshCurrentPlan(dayID: originalDay, studentID: StudentDemoSeed.studentID)
  #expect(model.planProjection?.cycleID == fixture.current.cycleID)
  model.completionPhase = .review
  await model.enterTraining()
  #expect(model.planProjection?.cycleID == fixture.current.cycleID)
  model.completionPhase = nil
  await model.enterTraining()
  #expect(model.currentDay?.id == fixture.upcoming.days.first?.id)
  #expect(model.showsHandoffNotice)
  model.dismissHandoffNotice()
  let relaunched = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(), effortDefaults: defaults)
  await relaunched.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  #expect(!relaunched.showsHandoffNotice)
}

extension HandoffWorkoutRepository {
  func advance() {
    var next = upcoming
    next.handoff = StudentPlanHandoff(
      currentPlanID: next.cycleID,
      plans: (current.handoff?.plans ?? []).map {
        .init(
          id: $0.id, name: $0.name, weeks: $0.weeks,
          completedTrainingDays: $0.id == next.cycleID ? 0 : $0.totalTrainingDays,
          totalTrainingDays: $0.totalTrainingDays, status: $0.id == next.cycleID ? .current : .past)
      })
    current = next
  }
}

@MainActor
@Test func handoffChatSharingUsesCurrentDayRatherThanUpcomingPrescription() async throws {
  let fixture = HandoffWorkoutFixture()
  let source = TodaySetRefSharingSource(
    studentID: StudentDemoSeed.studentID,
    plans: fixture.repository, logs: InMemoryStudentTrainingLogRepository(),
    videoManager: VideoUploadServices.demo().manager)
  let candidates = try await source.loadCandidates()
  let cursor = try #require(StudentPlanSequence.cursorDay(in: fixture.current))
  let expectedIDs = Set(cursor.exercises.flatMap(\.prescribedSets).map(\.id))
  #expect(!candidates.isEmpty)
  #expect(candidates.allSatisfy { $0.source.planSetId.map(expectedIDs.contains) == true })
  #expect(
    candidates.allSatisfy {
      $0.source.dayDate == cursor.date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    })
}

@MainActor
@Test func handoffCompletedSetDismissesNoticeWithoutTappingClose() async throws {
  let fixture = HandoffWorkoutFixture()
  await fixture.repository.advance()
  let defaults = try #require(UserDefaults(suiteName: "handoff-set-\(UUID())"))
  let model = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(), effortDefaults: defaults)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  #expect(model.showsHandoffNotice)
  #expect(await model.commitSet(rowIndex: 0))
  #expect(!model.showsHandoffNotice)
  let relaunched = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(), effortDefaults: defaults)
  await relaunched.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  #expect(!relaunched.showsHandoffNotice)
}

@MainActor
@Test func handoffPendingCompletionKeepsOriginalDayUntilAcknowledged() async throws {
  let fixture = HandoffWorkoutFixture()
  let queue = try SetSyncQueue(
    studentID: StudentDemoSeed.studentID, storage: MemorySetSyncStorage()
  ) {
    .planned($0.plannedLog)
  }
  let model = TodayWorkoutViewModel(
    plans: fixture.repository,
    logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  let oldDay = try #require(model.currentDay)
  try queue.completionGate.request(dayID: oldDay.id)
  await fixture.repository.advance()
  await model.enterTraining()
  #expect(model.currentDay?.id == oldDay.id)
  #expect(model.planProjection?.cycleID == fixture.current.cycleID)
  try queue.completionGate.forget(dayID: oldDay.id)
  await model.enterTraining()
  #expect(model.planProjection?.cycleID == fixture.upcoming.cycleID)
  await model.browseAdjacentPlan(forward: false)
  #expect(model.planProjection?.cycleID == fixture.current.cycleID)
  #expect(model.currentDay?.id == fixture.current.days.last?.id)
  #expect(!model.isPreviewingPlan)
  await model.returnToCurrentPlan()
  #expect(model.planProjection?.cycleID == fixture.upcoming.cycleID)
}

@MainActor
@Test(arguments: [false, true])
func handoffAccountChangeDiscardsPreviousAccountPlan(previewing: Bool) async throws {
  let fixture = HandoffWorkoutFixture()
  let model = TodayWorkoutViewModel(
    plans: fixture.repository, logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  if previewing { await model.browseAdjacentPlan(forward: true) }
  await fixture.repository.advance()
  await model.load(dayID: nil, studentID: UUID())
  #expect(model.planProjection?.cycleID == fixture.upcoming.cycleID)
  #expect(model.currentDay?.id == fixture.upcoming.days.first?.id)
  #expect(!model.isPreviewingPlan)
  #expect(!model.browsingPastPlan)
  #expect(model.handoff?.currentPlanID == fixture.upcoming.cycleID)
}

@MainActor
@Test func handoffNoticeSkipsEmptyPlansBetweenCycles() async throws {
  let fixture = HandoffWorkoutFixture()
  await fixture.repository.advanceWithEmptyPredecessor()
  let defaults = try #require(UserDefaults(suiteName: "handoff-empty-\(UUID())"))
  let model = TodayWorkoutViewModel(
    plans: fixture.repository, logs: InMemoryStudentTrainingLogRepository(),
    effortDefaults: defaults)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  #expect(model.showsHandoffNotice)
}

extension HandoffWorkoutRepository {
  func advanceWithEmptyPredecessor() {
    advance()
    guard let handoff = current.handoff else { return }
    var entries = handoff.plans
    entries.insert(
      .init(
        id: UUID(), name: "Empty", weeks: 1, completedTrainingDays: 0,
        totalTrainingDays: 0, status: .past), at: 1)
    current.handoff = StudentPlanHandoff(currentPlanID: current.cycleID, plans: entries)
  }
}

@MainActor
@Test(arguments: [false, true])
func handoffReturnWhilePendingUsesCachedCurrent(completionPending: Bool) async throws {
  let fixture = HandoffWorkoutFixture()
  let queue = try SetSyncQueue(
    studentID: StudentDemoSeed.studentID, storage: MemorySetSyncStorage()
  ) { .planned($0.plannedLog) }
  let model = TodayWorkoutViewModel(
    plans: fixture.repository, logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  let cursorID = try #require(model.currentDay?.id)
  if completionPending {
    try queue.completionGate.request(dayID: cursorID)
  } else {
    #expect(await model.commitSet(rowIndex: 0))
  }
  await model.browseAdjacentPlan(forward: true)
  #expect(model.isPreviewingPlan)
  await fixture.repository.advance()
  await model.returnToCurrentPlan()
  #expect(!model.isPreviewingPlan)
  #expect(model.planProjection?.cycleID == fixture.current.cycleID)
  #expect(model.currentDay?.id == cursorID)
}

@MainActor
@Test func handoffReturnHonorsAuthoritativeNoPlan() async throws {
  let fixture = HandoffWorkoutFixture()
  let model = TodayWorkoutViewModel(
    plans: fixture.repository, logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  await model.browseAdjacentPlan(forward: true)
  #expect(model.isPreviewingPlan)
  await fixture.repository.removeCurrentPlan()
  await model.returnToCurrentPlan()
  #expect(!model.isPreviewingPlan)
  #expect(model.planProjection == nil)
  #expect(model.currentDay == nil)
}

@MainActor
@Test func handoffNoticeIgnoresCompletedLogsFromOtherCycles() async throws {
  let fixture = HandoffWorkoutFixture()
  await fixture.repository.advance()
  let oldLog = StudentSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planExerciseID: UUID(),
    exerciseID: fixture.current.days[0].exercises[0].exercise.id, setIndex: 0,
    loggedAt: fixture.upcoming.startDate, weightKg: 100, reps: 5, rpe: 8,
    completed: true, failed: false)
  let defaults = try #require(UserDefaults(suiteName: "handoff-other-cycle-\(UUID())"))
  let model = TodayWorkoutViewModel(
    plans: fixture.repository, logs: InMemoryStudentTrainingLogRepository(seed: [oldLog]),
    effortDefaults: defaults, now: { fixture.upcoming.startDate })
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  #expect(model.showsHandoffNotice)
}

@MainActor
@Test func handoffAbandonedPastTailCannotBeRecorded() async throws {
  let fixture = HandoffWorkoutFixture()
  await fixture.repository.advance()
  let logs = InMemoryStudentTrainingLogRepository()
  let queue = try SetSyncQueue(
    studentID: StudentDemoSeed.studentID, storage: MemorySetSyncStorage()
  ) { .planned($0.plannedLog) }
  let model = TodayWorkoutViewModel(plans: fixture.repository, logs: logs, setSyncQueue: queue)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  await model.browseAdjacentPlan(forward: false)
  #expect(model.browsingPastPlan)
  let drafts = model.currentDrafts
  model.updateWeight(rowIndex: 0, weight: 999)
  #expect(model.currentDrafts == drafts)
  #expect(!(await model.commitSet(rowIndex: 0)))
  #expect(await model.ensureLoggedSetID(rowIndex: 0) == nil)
  #expect(queue.records.isEmpty)
  #expect(queue.completionGate.pendingDays.isEmpty)
}

@MainActor
@Test(arguments: [false, true])
func handoffColdStartKeepsPendingCycleUntilAcknowledged(preloaded: Bool) async throws {
  let fixture = HandoffWorkoutFixture()
  let storage = MemorySetSyncStorage()
  let dayID = try #require(fixture.current.days.last?.id)
  let original = try SetSyncQueue(studentID: StudentDemoSeed.studentID, storage: storage) {
    .planned($0.plannedLog)
  }
  try original.completionGate.request(dayID: dayID)
  await fixture.repository.advance()
  let restored = try SetSyncQueue(studentID: StudentDemoSeed.studentID, storage: storage) {
    .planned($0.plannedLog)
  }
  let model = TodayWorkoutViewModel(
    plans: fixture.repository, logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: restored)
  await model.load(
    dayID: nil, studentID: StudentDemoSeed.studentID,
    preloadedPlan: preloaded ? fixture.upcoming : nil)
  #expect(model.planProjection?.cycleID == fixture.current.cycleID)
  #expect(model.currentDay?.id == dayID)
  try restored.completionGate.forget(dayID: dayID)
  await model.enterTraining()
  #expect(model.planProjection?.cycleID == fixture.upcoming.cycleID)
}

extension HandoffWorkoutRepository {
  func fetchPlan(containing dayID: UUID, studentID: UUID) async throws -> StudentPlanView? {
    [original, upcoming].first { $0.days.contains { $0.id == dayID } }
  }
}
