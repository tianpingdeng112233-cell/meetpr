import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Supplies live video conditions to the existing durable completion gate.
@Observable @MainActor final class VideoCompletionCoordinator {
  private weak var queue: SetSyncQueue?
  let videos: VideoUploadManager
  private let plans: any StudentPlanRepository
  private(set) var completed: [UUID: PlanDayCompletion] = [:]
  private(set) var revision = 0
  var isCurrentAccount: @MainActor () async -> Bool = { true }
  private var active = true
  private var generation = 0
  private var refreshTask: Task<Void, Never>?
  private var needsRefresh = false
  private var timeoutCancellation: Task<Void, Never>?

  init(queue: SetSyncQueue, plans: any StudentPlanRepository, videos: VideoUploadManager) {
    self.queue = queue
    self.plans = plans
    self.videos = videos
  }

  func start() { active = true }

  func stop() {
    active = false
    generation += 1
    guard let queue else { return }
    var destinations: [UploadFailureDestination] = []
    for dayID in queue.completionGate.pendingDays {
      guard let wait = queue.completionGate.videoWait(dayID: dayID), wait.timeoutNotified,
        videos.now() < wait.startedAt.addingTimeInterval(30 * 60)
      else { continue }
      // A future system request is not a delivered notification. Persist its
      // cancellation before stopping the account so an overdue login can retry.
      do { try queue.completionGate.resetCancelledTimeout(dayID: dayID) } catch { continue }
      destinations.append(timeoutDestination(dayID: dayID, wait: wait))
    }
    let previous = timeoutCancellation
    let notifier = videos.failureNotifier
    timeoutCancellation = Task {
      await previous?.value
      for destination in destinations {
        await notifier.cancelCompletionTimeout(destination: destination)
      }
    }
  }

  private func finishTimeoutCancellation() async {
    while let task = timeoutCancellation {
      let generation = self.generation
      await task.value
      if generation == self.generation { timeoutCancellation = nil }
    }
  }

  func refresh() async {
    await finishTimeoutCancellation()
    // An event arriving during an awaited read must get a fresh pass before the
    // background URLSession caller is allowed to acknowledge its OS token.
    needsRefresh = true
    if let refreshTask {
      await refreshTask.value
      return
    }
    let task = Task { [weak self] in
      guard let self else { return }
      while self.needsRefresh && self.active {
        self.needsRefresh = false
        await self.refreshWaitingDays()
      }
    }
    refreshTask = task
    await task.value
    refreshTask = nil
  }

  private func refreshWaitingDays() async {
    guard active, let queue, await isCurrentAccount() else { return }
    let generation = self.generation
    for dayID in queue.completionGate.pendingDays + queue.completionGate.notificationDays {
      guard active, generation == self.generation,
        let wait = queue.completionGate.videoWait(dayID: dayID)
      else { continue }
      do { try await refresh(dayID: dayID, wait: wait, queue: queue, generation: generation) } catch
      {
        // Keep the durable intent for the next delivery/foreground tick.
      }
    }
  }

  private func refresh(
    dayID: UUID, wait: WorkoutCompletionGate.VideoWait,
    queue: SetSyncQueue, generation: Int
  ) async throws {
    let snapshot = try await dayVideos(wait.trainingDate, studentID: queue.studentID)
    guard active, generation == self.generation, await isCurrentAccount() else { return }
    if let result = queue.completionGate.completedResult(dayID: dayID) {
      try await notifyCompletion(result, wait: wait, queue: queue)
      return
    }
    let delivered = snapshot.delivered
    await updateTimeout(
      dayID: dayID, wait: wait, delivered: delivered,
      outstanding: snapshot.outstandingCount, queue: queue)
    guard active, generation == self.generation else { return }
    if !delivered { try queue.completionGate.markTimeoutScheduled(dayID: dayID) }
    if let result = try await queue.completionGate.completeIfReady(
      dayID: dayID, setsSynced: queue.pendingCount(dayID: dayID) == 0,
      videosDelivered: delivered,
      complete: {
        try await self.complete(dayID: dayID, wait: wait, queue: queue, generation: generation)
      })
    {
      try await notifyCompletion(result, wait: wait, queue: queue)
    }
  }

  private func complete(
    dayID: UUID, wait: WorkoutCompletionGate.VideoWait,
    queue: SetSyncQueue, generation: Int
  ) async throws -> PlanDayCompletion {
    if let day = try await plans.fetchDay(studentID: queue.studentID, dayID: dayID),
      let date = day.completedAt
    {
      return PlanDayCompletion(
        id: dayID, dayID: dayID, studentID: queue.studentID,
        source: day.completionSource ?? "manual", completedAt: date)
    }
    // Both groups and videos may have changed while the plan read was suspended.
    let latest = try await dayVideos(wait.trainingDate, studentID: queue.studentID)
    guard active, generation == self.generation, await isCurrentAccount(),
      queue.pendingCount(dayID: dayID) == 0, latest.delivered
    else { throw CancellationError() }
    return try await plans.completeDay(id: dayID, studentID: queue.studentID)
  }

  private func updateTimeout(
    dayID: UUID, wait: WorkoutCompletionGate.VideoWait,
    delivered: Bool, outstanding: Int, queue: SetSyncQueue
  ) async {
    let destination = timeoutDestination(dayID: dayID, wait: wait)
    if delivered {
      if wait.timeoutNotified {
        if videos.now() < wait.startedAt.addingTimeInterval(30 * 60) {
          try? queue.completionGate.resetCancelledTimeout(dayID: dayID)
        }
        await videos.failureNotifier.cancelCompletionTimeout(destination: destination)
      }
      return
    }
    let deadline = wait.startedAt.addingTimeInterval(30 * 60)
    guard !wait.timeoutNotified || videos.now() < deadline else { return }
    await videos.failureNotifier.scheduleCompletionTimeout(
      count: outstanding, deadline: deadline,
      destination: destination)
  }

  private func notifyCompletion(
    _ result: PlanDayCompletion,
    wait: WorkoutCompletionGate.VideoWait, queue: SetSyncQueue
  ) async throws {
    let generation = self.generation
    let records = try await dayVideos(wait.trainingDate, studentID: queue.studentID).records
    guard active, await isCurrentAccount() else { return }
    await videos.failureNotifier.notifyWorkoutCompleted(
      count: records.count,
      destination: UploadFailureDestination(
        setLogID: records.first?.setLogID ?? result.dayID,
        trainingDate: wait.trainingDate))
    guard active, generation == self.generation, await isCurrentAccount() else { return }
    try queue.completionGate.forget(dayID: result.dayID)
    completed[result.dayID] = result
    revision += 1
  }

  func deferIfNeeded(dayID: UUID, trainingDate: Date, startedAt: Date) async throws -> Bool {
    await finishTimeoutCancellation()
    guard active, let queue else { throw CancellationError() }
    let generation = self.generation
    let attachments = try await dayVideos(trainingDate, studentID: queue.studentID)
    guard active, generation == self.generation else { throw CancellationError() }
    guard !attachments.delivered else { return false }
    try queue.completionGate.waitForVideos(
      dayID: dayID, trainingDate: trainingDate, startedAt: startedAt)
    guard let wait = queue.completionGate.videoWait(dayID: dayID) else { throw CancellationError() }
    // Only local persistence and timeout registration precede the reward. The
    // completion endpoint/notification must not hold the reward page hostage.
    await updateTimeout(
      dayID: dayID, wait: wait, delivered: false,
      outstanding: attachments.outstandingCount, queue: queue)
    guard active, generation == self.generation else { throw CancellationError() }
    try queue.completionGate.markTimeoutScheduled(dayID: dayID)
    Task { await self.refresh() }
    return true
  }

  private func timeoutDestination(dayID: UUID, wait: WorkoutCompletionGate.VideoWait)
    -> UploadFailureDestination
  {
    UploadFailureDestination(setLogID: dayID, trainingDate: wait.trainingDate)
  }

  private func dayVideos(_ date: Date, studentID: UUID) async throws -> VideoDeliverySnapshot {
    try await videos.deliverySnapshot(studentID: studentID, trainingDate: date)
  }
}
