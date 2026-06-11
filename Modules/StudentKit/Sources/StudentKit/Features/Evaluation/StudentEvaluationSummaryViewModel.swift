import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Student-side evaluation summary presentation state (spec 033 §12):
/// dashboard card visibility (unread), the "我的" tab red dot, and the
/// "waiting for the first regular plan" row.
@Observable
@MainActor
public final class StudentEvaluationSummaryViewModel {
  public private(set) var summary: EvaluationSummary?
  public private(set) var isUnread = false
  public private(set) var currentPlan: StudentPlanView?

  @ObservationIgnored private let summaries: any EvaluationSummaryRepository
  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let readStore: any EvaluationSummaryReadStoring
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private var studentID: UUID?

  public init(
    summaries: any EvaluationSummaryRepository,
    plans: any StudentPlanRepository,
    readStore: any EvaluationSummaryReadStoring,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.summaries = summaries
    self.plans = plans
    self.readStore = readStore
    self.now = now
  }

  /// Dashboard card shows only while unread (D7); opening the full text
  /// marks it read and collapses the card.
  public var showsDashboardCard: Bool {
    summary != nil && isUnread
  }

  /// "教练正在为你排第一份正式计划" — until a regular (non-adaptation)
  /// published plan exists (wiki §6.2).
  public var showsAwaitingFirstPlan: Bool {
    guard summary != nil else { return false }
    return EvaluationSummaryPresentation.awaitsFirstRegularPlan(currentPlan)
  }

  /// "我的" tab red dot (1 while unread).
  public var unreadBadgeCount: Int {
    isUnread ? 1 : 0
  }

  public func load(studentID: UUID) async {
    self.studentID = studentID
    summary = try? await summaries.fetchSummary(studentID: studentID)
    currentPlan = try? await plans.fetchCurrentPlan(studentID: studentID)
    recomputeUnread()
  }

  /// Opening the full text writes the local read timestamp (D7).
  public func markRead() {
    guard let studentID, let summary else { return }
    // Stamp with the summary's own last_updated_at (not local now) so a
    // skewed device clock can't immediately re-flag it unread.
    let stamp = max(summary.lastUpdatedAt, now())
    readStore.markRead(studentID: studentID, at: stamp)
    recomputeUnread()
  }

  private func recomputeUnread() {
    guard let studentID, let summary else {
      isUnread = false
      return
    }
    isUnread = EvaluationSummaryPresentation.isUnread(
      summary: summary,
      lastReadAt: readStore.lastReadAt(studentID: studentID)
    )
  }
}

/// Pure presentation rules (spec 033 §12) — kept off the view model for
/// isolated tests.
public enum EvaluationSummaryPresentation {
  public static func isUnread(summary: EvaluationSummary, lastReadAt: Date?) -> Bool {
    guard let lastReadAt else { return true }
    return summary.lastUpdatedAt > lastReadAt
  }

  /// True while no regular published plan exists — an adaptation week does
  /// not count as the first regular plan.
  public static func awaitsFirstRegularPlan(_ plan: StudentPlanView?) -> Bool {
    guard let plan else { return true }
    return plan.planKind == .adaptation
  }
}
