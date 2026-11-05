import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Suite @MainActor struct OfflineSetRecordingTests {
  @Test func mainSetAndAccessoryReturnBeforeNetworkAndRefreshKeepsEdits() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let logs = OfflineSetTestRepository()
    let sender = SetSyncSender(logs: logs)
    let queue = try SetSyncQueue(
      studentID: student, storage: MemorySetSyncStorage(), send: sender.send)
    let model = TodayWorkoutViewModel(plans: plans, logs: logs, setSyncQueue: queue)
    await model.load(dayID: plan.days[0].id, studentID: student)
    model.updateWeight(rowIndex: 0, weight: 105)
    #expect(await model.commitSet(rowIndex: 0))
    #expect(model.currentDrafts?.first?.completed == true)
    #expect(model.restTimer != nil)
    #expect(model.actionErrorMessage == nil)
    #expect(queue.pendingCount == 1)
    await model.load(dayID: plan.days[0].id, studentID: student)
    #expect(model.currentDrafts?.first?.completed == true)
    #expect(model.currentDrafts?.first?.actualWeight == 105)
    await queue.drain()
    #expect(queue.pendingCount == 1)
    #expect(model.actionErrorMessage == nil)
  }

  @Test func pendingSetsTimeoutWithoutRewardOrCompletionThenRetrySucceeds() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let logs = InMemoryStudentTrainingLogRepository()
    let sender = SetSyncSender(logs: logs)
    let queue = try SetSyncQueue(
      studentID: student, storage: MemorySetSyncStorage(), send: sender.send)
    let clock = SetSyncTestClock()
    let model = TodayWorkoutViewModel(
      plans: plans, logs: logs, setSyncQueue: queue,
      setSyncSleep: { await clock.sleep() })
    await model.load(dayID: plan.days[0].id, studentID: student)
    #expect(await model.commitSet(rowIndex: 0))
    let attempt = Task { await model.completeCurrentDay() }
    await clock.waitUntilSleeping()
    #expect(model.completionPhase == nil)
    clock.advance()
    #expect(!(await attempt.value))
    #expect(model.completionPhase == nil)
    #expect(
      try await plans.fetchDay(studentID: student, dayID: plan.days[0].id)?.completedAt == nil)
    let retry = Task { await model.completeCurrentDay() }
    await clock.waitUntilSleeping()
    await queue.drain()
    #expect(await retry.value)
    #expect(model.completionPhase == .celebration)
    #expect(
      try await plans.fetchDay(studentID: student, dayID: plan.days[0].id)?.completedAt != nil)
    clock.advance()
  }

  @Test func missingPlanExerciseUsesOriginalCatalogIdentity() async throws {
    let logs = OfflineSetTestRepository(missing: true)
    let day = UUID()
    let sender = SetSyncSender(logs: logs, plans: SetSyncPlanFixture(dayID: day))
    let queue = try SetSyncQueue(
      studentID: UUID(), storage: MemorySetSyncStorage(), send: sender.send)
    var draft = SetSyncQueueTests.draft()
    draft.completed = true
    draft.actualWeight = 105
    draft.actualReps = 3
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: draft)
    await queue.drain()
    let saved = try #require(await logs.added.first)
    #expect(saved.planDayID == day)
    #expect(saved.exerciseID == draft.exerciseID)
    #expect(saved.weightKg == 105)
    #expect(saved.reps == 3)
    #expect(queue.pendingCount == 0)
  }

  @Test func sharedUnpublishedErrorWithoutAuthoritativeDeletionStaysRejected() async throws {
    let logs = OfflineSetTestRepository(missing: true)
    let sender = SetSyncSender(logs: logs)
    let queue = try SetSyncQueue(
      studentID: UUID(), storage: MemorySetSyncStorage(), send: sender.send)
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: SetSyncQueueTests.draft())
    await queue.drain()
    #expect(await logs.added.isEmpty)
    #expect(queue.pendingCount == 1)
    #expect(queue.hasRejected(dayID: day))
  }

  @Test(arguments: ["present", "missingDay", "unpublished", "offline"])
  func conversionRequiresFreshProofOfDeletion(scenario: String) async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let exercise = day.exercises[0]
    let logs = OfflineSetTestRepository(missing: true)
    let plans = SetSyncPlanFixture(
      dayID: scenario == "missingDay" ? UUID() : day.id,
      exercises: scenario == "present" ? day.exercises : [],
      failure: scenario == "offline" ? URLError(.notConnectedToInternet) : nil,
      hasPlan: scenario != "unpublished")
    let sender = SetSyncSender(logs: logs, plans: plans)
    let queue = try SetSyncQueue(
      studentID: student, storage: MemorySetSyncStorage(), send: sender.send)
    let draft = TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: exercise.id, exerciseID: exercise.exercise.id,
      exerciseName: "Bench", isAccessory: false,
      prescribed: PrescribedSet(id: UUID(), setIndex: 0, reps: 5))
    try queue.enqueue(dayID: day.id, trainingDate: Date(), draft: draft)
    await queue.drain()
    #expect(await logs.added.isEmpty)
    #expect(queue.pendingCount == 1)
    #expect(queue.hasRejected(dayID: day.id) == (scenario != "offline"))
  }

  @Test func syncBindsTheExistingPendingVideo() async throws {
    let repository = InMemoryVideoAttachmentRepository()
    let directory = FileManager.default.temporaryDirectory.appending(path: "sync-video-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let manager = VideoUploadManager(
      service: MockVideoUploadService(), exporter: MockVideoExporter(), repository: repository,
      configuration: VideoUploadHarness.testConfiguration(), filesDirectory: directory)
    let student = UUID()
    let date = Date()
    let draft = SetSyncQueueTests.draft()
    let source = try makeTemporaryVideoSource()
    defer { try? FileManager.default.removeItem(at: source) }
    let pending = try await manager.retainForSet(
      sourceURL: source, draftID: draft.id, studentID: student, trainingDate: date)
    let sender = SetSyncSender(logs: InMemoryStudentTrainingLogRepository(), videos: manager)
    let queue = try SetSyncQueue(
      studentID: student, storage: MemorySetSyncStorage(), send: sender.send)
    try queue.enqueue(dayID: UUID(), trainingDate: date, draft: draft)
    await queue.drain()
    let bound = try #require(try await repository.fetch(id: pending.id))
    #expect(bound.pendingDraftID == nil)
    #expect(bound.setLogID == queue.records.first?.draft.loggedSetID)
    #expect(queue.pendingCount == 0)
  }
}

actor OfflineSetTestRepository: StudentAddedLogRepository {
  let missing: Bool
  var added: [StudentAddedSetLog] = []
  init(missing: Bool = false) { self.missing = missing }
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    if missing {
      throw APIError.httpStatus(400, Data(#"{"error":"SETS_PLAN_EXERCISE_NOT_PUBLISHED"}"#.utf8))
    }
    throw URLError(.notConnectedToInternet)
  }
  func fetchLogs(studentID: UUID, in range: ClosedRange<Date>) -> [StudentSetLog] { [] }
  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) -> [StudentSetLog] { [] }
  func fetchAllLogs(studentID: UUID, in range: ClosedRange<Date>) -> StudentWorkoutLogs {
    StudentWorkoutLogs(planned: [], added: added)
  }
  func recordAddedSet(_ log: StudentAddedSetLog) -> StudentAddedSetLog {
    added.append(log)
    return log
  }
  func deleteAddedSet(id: UUID, studentID: UUID) { added.removeAll { $0.id == id } }
}

struct SetSyncPlanFixture: StudentPlanRepository {
  let dayID: UUID
  var exercises: [StudentPlanExercise] = []
  var failure: URLError?
  var hasPlan = true
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    // The sender must use refresh, not this potentially stale lookup.
    throw URLError(.resourceUnavailable)
  }
  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    if let failure { throw failure }
    guard hasPlan else { return nil }
    return StudentPlanView(
      cycleID: UUID(), weekIndex: 1, startDate: Date(), endDate: Date(),
      days: [StudentPlanDay(id: dayID, date: Date(), exercises: exercises)])
  }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { [] }
}
