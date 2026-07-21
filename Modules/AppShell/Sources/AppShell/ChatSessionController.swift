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

  @ObservationIgnored private let invalidationRouter: ChatBindingInvalidationRouter

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
  }

  public func cancelAllAndWaitForCleanup() async {
    guard let context else {
      return
    }
    context.inbox.stopPolling()
    await context.sendCoordinator.cancelAllAndWaitForCleanup()
    context.inbox.clear()
    self.context = nil
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
