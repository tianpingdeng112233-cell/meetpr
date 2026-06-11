import CoreModels
import Foundation
import Observation
import RepositoryContracts

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

  private let bind: any BindRepository

  public init(bind: any BindRepository) {
    self.bind = bind
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
      cancelError = "取消失败,请重试"
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
      return "\(days) 天 \(hours) 小时"
    }
    if hours > 0 {
      return "\(hours) 小时 \(minutes) 分"
    }
    return "\(minutes) 分钟"
  }
}
