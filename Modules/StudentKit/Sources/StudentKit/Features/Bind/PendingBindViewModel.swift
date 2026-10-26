import Analytics
import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// AppShell owns OS notification registration; StudentKit only requests it
/// after an explicit user action. Demo/macOS callers can omit this bridge.
public struct StudentNotificationPermissionActions: Sendable {
  let canRequest: @MainActor @Sendable () async -> Bool
  let request: @MainActor @Sendable () async -> Bool?

  public init(
    canRequest: @escaping @MainActor @Sendable () async -> Bool = { false },
    request: @escaping @MainActor @Sendable () async -> Bool? = { nil }
  ) {
    self.canRequest = canRequest
    self.request = request
  }
}

@Observable
@MainActor
public final class PendingBindViewModel {
  public enum CancelOutcome: Equatable, Sendable {
    /// DELETE succeeded → back to the enter-code page.
    case cancelled
    /// 409 BIND_REQUEST_NOT_PENDING — the coach responded first. Not an
    /// error from the student's perspective (spec 031 risk 4): reload mine
    /// and converge silently.
    case alreadyResponded
  }

  public private(set) var isCancelling = false
  public private(set) var cancelError: String?
  public private(set) var canRequestNotificationPermission = false
  public private(set) var isRequestingNotificationPermission = false

  private let bind: any BindRepository
  private let notificationPermission: StudentNotificationPermissionActions

  public init(
    bind: any BindRepository,
    notificationPermission: StudentNotificationPermissionActions = .init()
  ) {
    self.bind = bind
    self.notificationPermission = notificationPermission
  }

  public func refreshNotificationPermission() async {
    canRequestNotificationPermission = await notificationPermission.canRequest()
  }

  public func requestNotificationPermission() async -> Bool? {
    guard canRequestNotificationPermission, !isRequestingNotificationPermission else { return nil }
    isRequestingNotificationPermission = true
    defer { isRequestingNotificationPermission = false }
    Analytics.shared.track(
      .notificationPermissionAction,
      props: ["source": .enumCase("pending_bind"), "stage": .enumCase("clicked")]
    )
    let result = await notificationPermission.request()
    if let result {
      Analytics.shared.track(
        .notificationPermissionAction,
        props: [
          "source": .enumCase("pending_bind"), "stage": .enumCase("resolved"),
          "result": .enumCase(result ? "allowed" : "denied"),
        ]
      )
    }
    await refreshNotificationPermission()
    return result
  }

  /// nil = stay (transport failure, inline error shown).
  public func cancel(requestId: UUID) async -> CancelOutcome? {
    isCancelling = true
    defer { isCancelling = false }
    cancelError = nil
    do {
      try await bind.cancelBindRequest(id: requestId)
      return .cancelled
    } catch BindRequestError.notPending, BindRequestError.notFound {
      return .alreadyResponded
    } catch {
      cancelError = StudentStrings.localized(.pendingBindViewModel001)
      return nil
    }
  }

  /// "已等待: 2 小时 14 分" — minute granularity, refreshed by TimelineView.
  public nonisolated static func waitingDescription(since submittedAt: Date, now: Date) -> String {
    let seconds = max(0, now.timeIntervalSince(submittedAt))
    let totalMinutes = Int(seconds / 60)
    let days = totalMinutes / (24 * 60)
    let hours = (totalMinutes % (24 * 60)) / 60
    let minutes = totalMinutes % 60

    if days > 0 {
      return StudentStrings.replacing(.pendingBindViewModel002, values: ["\(days)", "\(hours)"])
    }
    if hours > 0 {
      return StudentStrings.replacing(.pendingBindViewModel003, values: ["\(hours)", "\(minutes)"])
    }
    return StudentStrings.replacing(.pendingBindViewModel004, values: ["\(minutes)"])
  }
}
