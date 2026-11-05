import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Suite @MainActor struct VideoCompletionReviewRegressionTests {
  @Test func logoutBeforeDeadlineRestoresOverdueTimeoutOnSameAccount() async throws {
    let fixture = try ReviewCompletionFixture()
    let clock = ReviewCompletionClock(fixture.start.addingTimeInterval(10 * 60))
    let notifier = ReviewCompletionNotifier(now: { clock.now() })
    let manager = fixture.manager(notifier: notifier, now: { clock.now() })
    try await fixture.repository.save(fixture.video())
    let first = VideoCompletionCoordinator(
      queue: fixture.queue, plans: fixture.plans, videos: manager)
    await first.refresh()
    first.stop()
    await notifier.waitForCancellation()
    clock.set(fixture.start.addingTimeInterval(40 * 60))
    let restored = try SetSyncQueue(studentID: fixture.student, storage: fixture.storage) {
      .planned($0.plannedLog)
    }
    let second = VideoCompletionCoordinator(queue: restored, plans: fixture.plans, videos: manager)
    await second.refresh()
    await second.refresh()
    #expect(await notifier.delivered == 1)
    #expect(restored.completionGate.pendingDays == [fixture.day.id])
    second.stop()
  }

  @Test func rewardDoesNotWaitForAutomaticCompletionRequest() async throws {
    let fixture = try ReviewCompletionFixture()
    let repository = FlipToDeliveredCompletionRepository(record: fixture.video())
    let manager = VideoUploadManager(
      service: LoopbackVideoUploadService(), exporter: MockVideoExporter(),
      repository: repository)
    let plans = SuspendedCompletionPlans(base: fixture.plans)
    let session = StudentSetSyncSession(
      queue: fixture.queue, plans: plans, videos: manager, onLogout: {})
    let workout = TodayWorkoutViewModel(
      plans: plans, logs: InMemoryStudentTrainingLogRepository(),
      setSyncQueue: fixture.queue)
    await workout.load(dayID: fixture.day.id, studentID: fixture.student)
    var holdFinished = false
    let hold = Task {
      let result = await workout.completeCurrentDay()
      holdFinished = true
      return result
    }
    await plans.waitForCompletionRequest()
    #expect(holdFinished)
    #expect(workout.completionPhase == .celebration)
    await plans.release()
    #expect(await hold.value)
    await fixture.queue.videoCompletion?.refresh()
    session.stop()
  }

  @Test func deletingFirstVideoStillCancelsScheduledTimeoutWhileGroupsArePending() async throws {
    let fixture = try ReviewCompletionFixture()
    let notifier = ReviewCompletionNotifier(now: { fixture.start })
    let manager = fixture.manager(notifier: notifier, now: { fixture.start })
    let first = fixture.video()
    let second = fixture.video()
    try await fixture.repository.save(first)
    try await fixture.repository.save(second)
    try fixture.queue.enqueue(
      dayID: fixture.day.id, trainingDate: fixture.day.scheduledDate,
      draft: SetSyncQueueTests.draft())
    let coordinator = VideoCompletionCoordinator(
      queue: fixture.queue, plans: fixture.plans, videos: manager)
    await coordinator.refresh()
    let scheduled = try #require(await notifier.pending)
    let removed = scheduled.setLogID == second.setLogID ? second : first
    var remaining = removed.id == first.id ? second : first
    try await fixture.repository.delete(id: removed.id)
    remaining.status = .uploaded
    try await fixture.repository.save(remaining)
    await coordinator.refresh()
    #expect(await notifier.pending == nil)
    #expect(fixture.queue.pendingCount(dayID: fixture.day.id) == 1)
    #expect(fixture.queue.completionGate.pendingDays == [fixture.day.id])
    coordinator.stop()
  }
}

@MainActor private struct ReviewCompletionFixture {
  let student = StudentDemoSeed.studentID
  let start = Date(timeIntervalSince1970: 10_000)
  let day: StudentPlanDay
  let plans: InMemoryStudentPlanRepository
  let storage = MemorySetSyncStorage()
  let queue: SetSyncQueue
  let repository = InMemoryVideoAttachmentRepository()

  init() throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    day = plan.days[0]
    plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    queue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    try queue.completionGate.request(dayID: day.id)
    try queue.completionGate.waitForVideos(
      dayID: day.id, trainingDate: day.scheduledDate, startedAt: start)
  }
  func video() -> VideoAttachment {
    VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: student, status: .pending,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1, recordedAt: start,
      trainingDate: day.scheduledDate)
  }
  func manager(notifier: any UploadFailureNotifying, now: @escaping @Sendable () -> Date)
    -> VideoUploadManager
  {
    VideoUploadManager(
      service: LoopbackVideoUploadService(), exporter: MockVideoExporter(),
      repository: repository, now: now, failureNotifier: notifier)
  }
}

private final class ReviewCompletionClock: @unchecked Sendable {
  private let lock = NSLock()
  private var date: Date
  init(_ date: Date) { self.date = date }
  func now() -> Date { lock.withLock { date } }
  func set(_ value: Date) { lock.withLock { date = value } }
}

private actor ReviewCompletionNotifier: UploadFailureNotifying {
  let now: @Sendable () -> Date
  var pending: UploadFailureDestination?
  var delivered = 0
  private var cancelled = false
  private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []
  init(now: @escaping @Sendable () -> Date) { self.now = now }
  func requestAuthorization() async {}
  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async {}
  func scheduleCompletionTimeout(count: Int, deadline: Date, destination: UploadFailureDestination)
    async
  {
    if now() >= deadline {
      delivered += 1
      pending = nil
    } else {
      pending = destination
    }
  }
  func cancelCompletionTimeout(destination: UploadFailureDestination) async {
    if pending == destination { pending = nil }
    cancelled = true
    for waiter in cancellationWaiters { waiter.resume() }
    cancellationWaiters = []
  }
  func waitForCancellation() async {
    if cancelled { return }
    await withCheckedContinuation { cancellationWaiters.append($0) }
  }
}

private actor SuspendedCompletionPlans: StudentPlanRepository {
  let base: InMemoryStudentPlanRepository
  private var started = false
  private var observers: [CheckedContinuation<Void, Never>] = []
  private var continuation: CheckedContinuation<Void, Never>?
  init(base: InMemoryStudentPlanRepository) { self.base = base }
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    try await base.fetchCurrentPlan(studentID: studentID)
  }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    try await base.fetchCycleDays(studentID: studentID)
  }
  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    started = true
    for observer in observers { observer.resume() }
    observers = []
    await withCheckedContinuation { continuation = $0 }
    return try await base.completeDay(id: id, studentID: studentID)
  }
  func waitForCompletionRequest() async {
    if started { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func release() {
    continuation?.resume()
    continuation = nil
  }
}

private actor FlipToDeliveredCompletionRepository: VideoAttachmentRepository {
  var record: VideoAttachment
  init(record: VideoAttachment) { self.record = record }
  func save(_ attachment: VideoAttachment) async throws { record = attachment }
  func persistUploadedPart(_ part: VideoUploadedPart, recordID: UUID, expectedUploadGeneration: Int)
    async throws -> VideoAttachment?
  { nil }
  func fetch(id: UUID) async throws -> VideoAttachment? { record }
  func fetch(setLogID: UUID) async throws -> [VideoAttachment] { [record] }
  func fetchAll(studentID: UUID) async throws -> [VideoAttachment] {
    let snapshot = record
    record.status = .uploaded
    return [snapshot]
  }
  func delete(id: UUID) async throws {}
  func playbackURL(for attachment: VideoAttachment) async throws -> URL? { nil }
}
