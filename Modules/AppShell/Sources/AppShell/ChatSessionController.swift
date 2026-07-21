import ChatUI
import Foundation
import Observation
import RepositoryContracts

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct ChatSessionContext {
  public let repository: any ChatRepository
  public let currentUserID: UUID
  public let inbox: ChatInboxViewModel
  public let sendCoordinator: ChatSendCoordinator

  public init(
    repository: any ChatRepository,
    currentUserID: UUID,
    inbox: ChatInboxViewModel,
    sendCoordinator: ChatSendCoordinator
  ) {
    self.repository = repository
    self.currentUserID = currentUserID
    self.inbox = inbox
    self.sendCoordinator = sendCoordinator
  }
}

/// Owns the authenticated user's chat graph for exactly one app session.
///
/// Role kits only receive this graph; they never construct chat repositories,
/// inboxes, or send coordinators themselves.
@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class ChatSessionController {
  public private(set) var context: ChatSessionContext?
  public private(set) var isChangingStudentBinding = false

  @ObservationIgnored private let invalidationRouter: ChatBindingInvalidationRouter
  @ObservationIgnored private var pendingStudentCoachID: UUID?
  /// Which coach the live student context was built for. Observed, because
  /// the root view gates on it: a context is only reusable for the same
  /// (user, coach) pair.
  public private(set) var activeStudentCoachID: UUID?
  /// Bumped whenever the session itself turns over (logout, user or role
  /// switch). An activation parked in an `await` captures this and refuses to
  /// publish if it no longer matches — the per-binding flags cannot express
  /// that, because logout resets them and a late activation would then pass.
  @ObservationIgnored private var activationGeneration: UInt64 = 0
  /// The teardown currently draining, if any. `context == nil` does not mean
  /// cleanup finished — it is cleared first so the UI drops the old graph
  /// immediately — so overlapping callers must join this instead.
  @ObservationIgnored private var teardownTask: Task<Void, Never>?
  @ObservationIgnored private var teardownToken: UInt64 = 0

  public init() {
    invalidationRouter = ChatBindingInvalidationRouter()
  }

  init(invalidationRouter: ChatBindingInvalidationRouter) {
    self.invalidationRouter = invalidationRouter
  }

  public func activateCoach(
    repository: any ChatRepository,
    currentUserID: UUID
  ) async {
    let generation = activationGeneration
    if context?.currentUserID == currentUserID {
      activeStudentCoachID = nil
      await invalidationRouter.useCoachNoOp()
      return
    }

    await cancelAllAndWaitForCleanup()
    await invalidationRouter.useCoachNoOp()
    // cancelAllAndWaitForCleanup bumps the generation itself, so compare
    // against that instead of the value captured on entry.
    let survivingGeneration = activationGeneration
    let onBindingInvalidated: @Sendable () async -> Void = { [invalidationRouter] in
      await invalidationRouter.route()
    }
    let inbox = ChatInboxViewModel(
      repository: repository,
      currentUserID: currentUserID,
      onBindingInvalidated: onBindingInvalidated
    )
    let sendCoordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID,
      onBindingInvalidated: onBindingInvalidated
    )
    guard survivingGeneration == activationGeneration else { return }
    context = ChatSessionContext(
      repository: repository,
      currentUserID: currentUserID,
      inbox: inbox,
      sendCoordinator: sendCoordinator
    )
    activeStudentCoachID = nil
  }

  public func activateStudent(
    repository: any ChatRepository,
    currentUserID: UUID,
    activeCoachID: UUID,
    refreshBinding: @escaping @MainActor @Sendable () async -> Void
  ) async {
    let generation = activationGeneration
    guard canActivateStudent(for: activeCoachID) else { return }
    if context?.currentUserID == currentUserID,
      activeStudentCoachID == activeCoachID
    {
      await invalidationRouter.useStudentHandler {
        await refreshBinding()
      }
      isChangingStudentBinding = false
      pendingStudentCoachID = nil
      return
    }

    await tearDownContext()
    await invalidationRouter.useStudentHandler {
      await refreshBinding()
    }

    // Both awaits above suspend. A later binding change can be prepared while
    // we are parked in them, and a logout can reset the per-binding flags — so
    // check the session generation too, which logout always advances.
    guard generation == activationGeneration,
      canActivateStudent(for: activeCoachID)
    else { return }

    let onBindingInvalidated: @Sendable () async -> Void = { [invalidationRouter] in
      await invalidationRouter.route()
    }
    let inbox = ChatInboxViewModel(
      repository: repository,
      currentUserID: currentUserID,
      onBindingInvalidated: onBindingInvalidated
    )
    let sendCoordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID,
      onBindingInvalidated: onBindingInvalidated
    )
    context = ChatSessionContext(
      repository: repository,
      currentUserID: currentUserID,
      inbox: inbox,
      sendCoordinator: sendCoordinator
    )
    activeStudentCoachID = activeCoachID
    isChangingStudentBinding = false
    pendingStudentCoachID = nil
  }

  public func prepareForStudentBindingChange(
    from oldCoachID: UUID?,
    to newCoachID: UUID?
  ) async {
    guard oldCoachID != newCoachID else { return }
    isChangingStudentBinding = true
    pendingStudentCoachID = newCoachID
    await tearDownContext()
  }

  public func canActivateStudent(for coachID: UUID) -> Bool {
    !isChangingStudentBinding || pendingStudentCoachID == coachID
  }

  public func reportBindingInvalidation() async {
    await invalidationRouter.route()
  }

  public func cancelAllAndWaitForCleanup() async {
    // Invalidate parked activations before draining: clearing the per-binding
    // flags below would otherwise let a late activation re-publish post-logout.
    activationGeneration &+= 1
    await tearDownContext()
    isChangingStudentBinding = false
    pendingStudentCoachID = nil
  }

  private func tearDownContext() async {
    // Join a teardown already in flight; a rebind drain and a logout can
    // overlap, and the second caller must not return before the first finishes.
    if let existing = teardownTask {
      await existing.value
    }

    guard let context else {
      activeStudentCoachID = nil
      return
    }
    self.context = nil
    activeStudentCoachID = nil

    teardownToken &+= 1
    let token = teardownToken
    let task = Task { @MainActor in
      context.inbox.stopPolling()
      await context.sendCoordinator.cancelAllAndWaitForCleanup()
      context.inbox.clear()
    }
    teardownTask = task
    await task.value
    if teardownToken == token {
      teardownTask = nil
    }
  }
}

actor ChatBindingInvalidationRouter {
  private var handler: (@Sendable () async -> Void)?
  private var isRouting = false

  func useCoachNoOp() {
    handler = nil
  }

  func useStudentHandler(_ handler: @escaping @Sendable () async -> Void) {
    self.handler = handler
  }

  func route() async {
    guard !isRouting, let handler else {
      return
    }
    isRouting = true
    await handler()
    isRouting = false
  }
}
