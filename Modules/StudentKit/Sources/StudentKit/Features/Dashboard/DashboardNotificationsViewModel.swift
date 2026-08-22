import ChatUI
import CoreModels
import Foundation
import Observation
import RepositoryContracts

protocol DashboardPlanSeenStoring: Sendable {
  func hasSeen(studentID: UUID, signature: DashboardPlanSignature) -> Bool
  func markSeen(studentID: UUID, signature: DashboardPlanSignature)
}

struct DashboardPlanSignature: Equatable, Hashable, Sendable {
  let rawValue: String

  init(plan: StudentPlanView) {
    rawValue = [
      plan.cycleID.uuidString,
      String(plan.weekIndex),
      String(Int(plan.startDate.timeIntervalSince1970)),
    ].joined(separator: ".")
  }
}

struct DashboardPlanNotice: Equatable, Sendable {
  let signature: DashboardPlanSignature
  let weekIndex: Int
  let occurredAt: Date
}

enum StudentConversationOpenResult: Equatable, Sendable {
  case opened(UUID)
  case noActiveCoach
  case bindRequired
  case failed
}

final class UserDefaultsDashboardPlanSeenStore: DashboardPlanSeenStoring, @unchecked Sendable {
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func hasSeen(studentID: UUID, signature: DashboardPlanSignature) -> Bool {
    defaults.bool(forKey: key(studentID: studentID, signature: signature))
  }

  func markSeen(studentID: UUID, signature: DashboardPlanSignature) {
    defaults.set(true, forKey: key(studentID: studentID, signature: signature))
  }

  private func key(studentID: UUID, signature: DashboardPlanSignature) -> String {
    "meetpr.dashboard.plan_seen.\(studentID.uuidString).\(signature.rawValue)"
  }
}

final class InMemoryDashboardPlanSeenStore: DashboardPlanSeenStoring, @unchecked Sendable {
  private var seen: Set<String>
  private let lock = NSLock()

  init(seed: Set<String> = []) {
    seen = seed
  }

  func hasSeen(studentID: UUID, signature: DashboardPlanSignature) -> Bool {
    lock.withLock { seen.contains(key(studentID: studentID, signature: signature)) }
  }

  func markSeen(studentID: UUID, signature: DashboardPlanSignature) {
    lock.withLock {
      _ = seen.insert(key(studentID: studentID, signature: signature))
    }
  }

  private func key(studentID: UUID, signature: DashboardPlanSignature) -> String {
    "\(studentID.uuidString).\(signature.rawValue)"
  }
}

@MainActor
struct StudentChatContext {
  let repository: any ChatRepository
  let currentUserID: UUID
  let inbox: ChatInboxViewModel
  let sendCoordinator: ChatSendCoordinator
  let setRefSharing: SetRefSharingContext?

  init(
    repository: any ChatRepository,
    currentUserID: UUID,
    inbox: ChatInboxViewModel,
    sendCoordinator: ChatSendCoordinator,
    setRefSharing: SetRefSharingContext? = nil
  ) {
    self.repository = repository
    self.currentUserID = currentUserID
    self.inbox = inbox
    self.sendCoordinator = sendCoordinator
    self.setRefSharing = setRefSharing
  }
}

/// One notification graph shared by all four coached-student tabs.
///
/// Plan-seen state, feedback/evaluation unread state, and the chat inbox all
/// live behind this single instance so opening or refreshing one tab cannot
/// leave another tab's bell stale.
@Observable
@MainActor
public final class StudentNotificationsCoordinator {
  enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(DashboardPlanNotice?)
    case error(String)
  }

  private(set) var state: State = .idle

  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let seenStore: any DashboardPlanSeenStoring
  @ObservationIgnored private let feedback: FeedbackInboxViewModel
  @ObservationIgnored private let evaluation: StudentEvaluationSummaryViewModel
  @ObservationIgnored let chatContext: StudentChatContext?
  @ObservationIgnored private let onBindingInvalidated: @Sendable () async -> Void
  let activeCoach: ActiveCoachContext?
  @ObservationIgnored private var currentStudentID: UUID?

  init(
    plans: any StudentPlanRepository,
    feedback: FeedbackInboxViewModel,
    evaluation: StudentEvaluationSummaryViewModel,
    activeCoach: ActiveCoachContext?,
    chatContext: StudentChatContext?,
    seenStore: any DashboardPlanSeenStoring = UserDefaultsDashboardPlanSeenStore(),
    onBindingInvalidated: @escaping @Sendable () async -> Void = {}
  ) {
    self.plans = plans
    self.feedback = feedback
    self.evaluation = evaluation
    self.activeCoach = activeCoach
    self.chatContext = chatContext
    self.seenStore = seenStore
    self.onBindingInvalidated = onBindingInvalidated
  }

  var planNotice: DashboardPlanNotice? {
    guard case .loaded(let notice) = state else {
      return nil
    }
    return notice
  }

  var feedbackUnreadCount: Int {
    feedback.unreadCount
  }

  var feedbackItems: [CoachFeedback] {
    feedback.items
  }

  var evaluationUnreadCount: Int {
    evaluation.unreadBadgeCount
  }

  var chatUnreadCount: Int {
    guard activeCoach != nil else { return 0 }
    return coachConversation?.unreadCount ?? 0
  }

  var totalUnreadCount: Int {
    (planNotice == nil ? 0 : 1)
      + feedbackUnreadCount
      + chatUnreadCount
    // Evaluation remains implemented for a future unseal, but the 2026-07-13
    // hard-seal decision is defer-not-delete: no evaluation ghost badge may
    // surface in the coached student's header while that flow is sealed.
  }

  var coachConversation: ChatConversation? {
    guard let coachID = activeCoach?.coachID else { return nil }
    return chatContext?.inbox.conversations.first { $0.otherPartyID == coachID }
  }

  func loadIfNeeded(studentID: UUID) async {
    guard state == .idle else { return }
    await reload(studentID: studentID)
  }

  func reload(studentID: UUID) async {
    currentStudentID = studentID
    let isInitialLoad = state == .idle
    if isInitialLoad { state = .loading }

    async let feedbackLoad: Void = feedback.load(studentID: studentID)
    async let evaluationLoad: Void = evaluation.load(studentID: studentID)
    async let chatLoad: Void = refreshChatIfAvailable()
    _ = await (feedbackLoad, evaluationLoad, chatLoad)

    do {
      guard let plan = try await plans.fetchCurrentPlan(studentID: studentID) else {
        state = .loaded(nil)
        return
      }
      let signature = DashboardPlanSignature(plan: plan)
      let notice =
        seenStore.hasSeen(studentID: studentID, signature: signature)
        ? nil
        : DashboardPlanNotice(
          signature: signature,
          weekIndex: plan.weekIndex,
          occurredAt: plan.startDate
        )
      state = .loaded(notice)
    } catch {
      if error.isTaskCancellation {
        if isInitialLoad { state = .idle }
        return
      }
      if case .loaded = state { return }
      state = .error(error.localizedDescription)
    }
  }

  func reloadVolatile(studentID: UUID) async {
    currentStudentID = studentID
    async let feedbackLoad: Void = feedback.load(studentID: studentID)
    async let chatLoad: Void = refreshChatIfAvailable()
    _ = await (feedbackLoad, chatLoad)
  }

  private func refreshChatIfAvailable() async {
    guard let chatContext, activeCoach != nil else { return }
    await chatContext.inbox.refresh()
  }

  func markCurrentPlanSeen() {
    guard let currentStudentID, let notice = planNotice else {
      return
    }
    seenStore.markSeen(studentID: currentStudentID, signature: notice.signature)
    state = .loaded(nil)
  }

  func markFeedbackRead(_ item: CoachFeedback) async {
    guard item.readAt == nil else { return }
    await feedback.markRead(item)
  }

  func startChatPolling() {
    guard activeCoach != nil else { return }
    chatContext?.inbox.startPolling()
  }

  func stopChatPolling() {
    chatContext?.inbox.stopPolling()
  }

  func openCoachConversation() async -> StudentConversationOpenResult {
    guard let activeCoach else {
      return .noActiveCoach
    }
    guard let chatContext else {
      return .failed
    }
    do {
      let conversation = try await chatContext.repository.openConversation(
        withOtherParty: activeCoach.coachID
      )
      await chatContext.inbox.refresh()
      return .opened(conversation.id)
    } catch {
      if error as? ChatRepositoryError == .bindRequired {
        await onBindingInvalidated()
        return .bindRequired
      }
      return .failed
    }
  }
}
