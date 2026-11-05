import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable @MainActor final class StudentSetSyncSession {
  let queue: SetSyncQueue
  private(set) var showsLogout = false
  private(set) var isUploadingForLogout = false
  private let plans: any StudentPlanRepository
  var onLogout: @MainActor () async -> Void
  private var logoutObserver: UUID?
  private var recovery: Task<Void, Never>?
  private var active = false
  private var videoEvents: Task<Void, Never>?

  init(
    queue: SetSyncQueue, plans: any StudentPlanRepository, videos: VideoUploadManager? = nil,
    onLogout: @escaping @MainActor () async -> Void
  ) {
    self.queue = queue
    self.plans = plans
    self.onLogout = onLogout
    if let videos {
      queue.videoCompletion = VideoCompletionCoordinator(queue: queue, plans: plans, videos: videos)
    }
  }

  static func live(
    studentID: UUID, plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository, videos: VideoUploadManager?,
    onLogout: @escaping @MainActor () async -> Void
  ) throws -> StudentSetSyncSession {
    let sender = SetSyncSender(logs: logs, plans: plans, videos: videos)
    let queue = try SetSyncQueue(
      studentID: studentID, storage: FileSetSyncStorage(), send: sender.send)
    return StudentSetSyncSession(queue: queue, plans: plans, videos: videos, onLogout: onLogout)
  }

  func start(network: (any UploadNetworkMonitoring)? = nil) {
    guard !active else { return }
    active = true
    queue.videoCompletion?.start()
    queue.start(network: network)
    recovery?.cancel()
    let restoredDays = queue.completionGate.pendingDays
    if let completion = queue.videoCompletion {
      videoEvents = Task { [weak completion] in
        guard let completion else { return }
        let events = await completion.videos.events()
        for await _ in events {
          guard !Task.isCancelled else { return }
          await completion.refresh()
        }
      }
    }
    recovery = Task { [weak self] in
      guard let self else { return }
      while self.active, !Task.isCancelled {
        await self.queue.videoCompletion?.refresh()
        await self.resumeRestoredCompletions(restoredDays)
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
      }
    }
  }

  private func resumeRestoredCompletions(_ restoredDays: [UUID]) async {
    for dayID in restoredDays where self.queue.completionGate.videoWait(dayID: dayID) == nil {
      guard self.active, !Task.isCancelled else { return }
      guard self.queue.completionGate.pendingDays.contains(dayID) else { continue }
      if await self.restoreVideoCondition(dayID: dayID) { continue }
      _ = try? await self.queue.completionGate.completeIfReady(
        dayID: dayID, setsSynced: self.queue.pendingCount(dayID: dayID) == 0,
        videosDelivered: true,
        complete: {
          // A response may have been lost immediately before process death.
          if let day = try await self.plans.fetchDay(
            studentID: self.queue.studentID, dayID: dayID),
            let completedAt = day.completedAt
          {
            return PlanDayCompletion(
              id: day.id, dayID: day.id, studentID: self.queue.studentID,
              source: day.completionSource ?? "manual", completedAt: completedAt)
          }
          return try await self.plans.completeDay(id: dayID, studentID: self.queue.studentID)
        })
    }
  }

  private func restoreVideoCondition(dayID: UUID) async -> Bool {
    guard let videos = queue.videoCompletion else { return false }
    guard await videos.isCurrentAccount() else {
      stop()
      return true
    }
    do {
      guard let day = try await plans.fetchDay(studentID: queue.studentID, dayID: dayID) else {
        return true
      }
      guard day.completedAt == nil else { return false }
      return try await videos.deferIfNeeded(
        dayID: dayID, trainingDate: day.scheduledDate,
        startedAt: queue.completionGate.requestedAt(dayID: dayID))
    } catch { return true }
  }

  func stop() {
    active = false
    recovery?.cancel()
    recovery = nil
    cancelLogout()
    videoEvents?.cancel()
    videoEvents = nil
    queue.videoCompletion?.stop()
    queue.stop()
  }

  func requestLogout() async {
    if queue.pendingCount == 0 {
      await logOutNow()
    } else {
      showsLogout = true
    }
  }

  func uploadThenLogout() {
    guard !isUploadingForLogout else { return }
    isUploadingForLogout = true
    logoutObserver = queue.observe { [weak self] in
      guard let self, self.isUploadingForLogout, self.queue.pendingCount == 0 else { return }
      Task { @MainActor [weak self] in
        guard let self, self.isUploadingForLogout else { return }
        await self.logOutNow()
      }
    }
    queue.start()
    queue.retryNow()
  }

  func cancelLogout() {
    isUploadingForLogout = false
    showsLogout = false
    if let logoutObserver { queue.removeObserver(logoutObserver) }
    logoutObserver = nil
  }

  func logOutNow() async {
    stop()
    await onLogout()
  }
}
