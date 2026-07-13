import Analytics
import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Coach receive queue (spec 033 §2-§5). The queue lives on the roster tab:
/// the section is hidden when empty and the tab badge adds `pendingCount`.
@Observable
@MainActor
final class BindQueueViewModel {
  enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
  }

  var state: LoadState = .idle
  private(set) var items: [CoachBindRequestItem] = []
  /// Queue-level recovery banner (spec 033 D12: every accept/reject 4xx →
  /// refresh + banner, never an in-place retry).
  var bannerMessage: String?
  /// Transient success feedback after accept.
  var toastMessage: String?

  var pendingCount: Int { items.count }

  @ObservationIgnored private let repository: any CoachBindQueueRepository
  @ObservationIgnored let now: @Sendable () -> Date

  init(
    repository: any CoachBindQueueRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.repository = repository
    self.now = now
  }

  func loadIfNeeded() async {
    guard state == .idle else { return }
    await refresh()
  }

  func refresh() async {
    if state == .idle { state = .loading }
    do {
      items = try await repository.fetchQueue()
      state = .loaded
    } catch {
      // Keep the last snapshot on transport failure; an empty failed queue
      // collapses the section, same as empty.
      if state != .loaded { state = .failed }
    }
  }

  /// True on success (caller refreshes the roster — a new student appeared).
  /// `skipReason` is only carried on the skip branch and only when non-blank
  /// (zod superRefine alignment, spec 033 §5).
  func accept(_ item: CoachBindRequestItem, skipEvaluation: Bool, skipReason: String?) async
    -> Bool
  {
    bannerMessage = nil
    let trimmedReason = skipReason?.trimmingCharacters(in: .whitespacesAndNewlines)
    let reason = (skipEvaluation && trimmedReason?.isEmpty == false) ? trimmedReason : nil
    do {
      let outcome = try await repository.accept(
        requestID: item.id,
        skipEvaluation: skipEvaluation,
        skipReason: reason
      )
      items.removeAll { $0.id == item.id }
      toastMessage =
        outcome.evaluation == nil ? "已接收" : "已接收,评估期 7 天开始"
      Analytics.shared.coachIntakeAction(
        skipEvaluation ? .acceptedSkip : .acceptedEvaluation,
        studentID: item.studentId)
      return true
    } catch let error as CoachBindQueueError {
      bannerMessage = Self.bannerText(for: error)
      await refresh()
      return false
    } catch {
      bannerMessage = "网络异常,请稍后重试"
      return false
    }
  }

  /// True on success. Silent rejection — no reason wire field (spec 033 D10).
  func reject(_ item: CoachBindRequestItem) async -> Bool {
    bannerMessage = nil
    do {
      try await repository.reject(requestID: item.id)
      items.removeAll { $0.id == item.id }
      Analytics.shared.coachIntakeAction(.rejected, studentID: item.studentId)
      return true
    } catch let error as CoachBindQueueError {
      bannerMessage = Self.bannerText(for: error)
      await refresh()
      return false
    } catch {
      bannerMessage = "网络异常,请稍后重试"
      return false
    }
  }

  static func bannerText(for error: CoachBindQueueError) -> String {
    switch error {
    case .expired: "该请求已过期"
    case .notPending, .notFound: "该请求已被处理"
    case .alreadyBound: "你们已是绑定关系"
    }
  }
}
