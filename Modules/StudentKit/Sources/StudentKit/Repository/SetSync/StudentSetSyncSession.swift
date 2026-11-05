import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable @MainActor final class StudentSetSyncSession {
  let queue: SetSyncQueue
  private(set) var showsLogout = false
  private(set) var isUploadingForLogout = false
  private let plans: any StudentPlanRepository
  private let onLogout: @MainActor () async -> Void
  private var logoutObserver: UUID?
  private var recovery: Task<Void, Never>?
  private var active = false

  init(
    queue: SetSyncQueue, plans: any StudentPlanRepository,
    onLogout: @escaping @MainActor () async -> Void
  ) {
    self.queue = queue
    self.plans = plans
    self.onLogout = onLogout
  }

  static func live(
    studentID: UUID, plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository, videos: VideoUploadManager?,
    onLogout: @escaping @MainActor () async -> Void
  ) throws -> StudentSetSyncSession {
    let sender = SetSyncSender(logs: logs, plans: plans, videos: videos)
    let queue = try SetSyncQueue(
      studentID: studentID, storage: FileSetSyncStorage(), send: sender.send)
    return StudentSetSyncSession(queue: queue, plans: plans, onLogout: onLogout)
  }

  func start(network: (any UploadNetworkMonitoring)? = nil) {
    active = true
    queue.start(network: network)
    recovery?.cancel()
    let restoredDays = queue.completionGate.pendingDays
    recovery = Task { [weak self] in
      guard let self else { return }
      while self.active, !Task.isCancelled {
        for dayID in restoredDays {
          guard self.active, !Task.isCancelled else { return }
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
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
      }
    }
  }

  func stop() {
    active = false
    recovery?.cancel()
    recovery = nil
    cancelLogout()
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
