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
    if context?.currentUserID == currentUserID {
      activeStudentCoachID = nil
      await invalidationRouter.useCoachNoOp()
      return
    }

    await cancelAllAndWaitForCleanup()
    await invalidationRouter.useCoachNoOp()
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
    activeStudentCoachID = nil
  }

  public func activateStudent(
    repository: any ChatRepository,
    currentUserID: UUID,
    activeCoachID: UUID,
    refreshBinding: @escaping @MainActor @Sendable () async -> Void
  ) async {
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

    // Both awaits above suspend, and a later binding change can be prepared
    // while we are parked in them. Publishing unconditionally would attach the
    // UI to a coach the user has already switched away from, so re-check that
    // this activation is still the one wanted before building the graph.
    guard canActivateStudent(for: activeCoachID) else { return }

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
    await tearDownContext()
    isChangingStudentBinding = false
    pendingStudentCoachID = nil
  }

  private func tearDownContext() async {
    guard let context else {
      activeStudentCoachID = nil
      return
    }
    self.context = nil
    activeStudentCoachID = nil
    context.inbox.stopPolling()
    await context.sendCoordinator.cancelAllAndWaitForCleanup()
    context.inbox.clear()
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
