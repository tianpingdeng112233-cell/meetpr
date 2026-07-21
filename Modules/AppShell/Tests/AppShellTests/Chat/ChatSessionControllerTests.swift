import ChatUI
import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func coachChatSessionUsesAuthenticatedUserAndReusesSessionGraph() async throws {
  let userID = UUID()
  let repository = InMemoryChatRepository(
    currentUserID: userID,
    seed: .coach()
  )
  let controller = ChatSessionController()

  await controller.activateCoach(repository: repository, currentUserID: userID)
  let firstInbox = try #require(controller.context?.inbox)
  let firstCoordinator = try #require(controller.context?.sendCoordinator)
  #expect(controller.context?.currentUserID == userID)

  await controller.activateCoach(repository: repository, currentUserID: userID)

  #expect(controller.context?.inbox === firstInbox)
  #expect(controller.context?.sendCoordinator === firstCoordinator)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func coachBindingInvalidationRouteIsNoOp() async {
  let probe = BindingRefreshProbe()
  let router = ChatBindingInvalidationRouter()
  await router.useStudentHandler {
    await probe.recordRefresh()
  }
  await router.route()
  #expect(await probe.refreshCount == 1)

  await router.useCoachNoOp()
  await router.route()

  #expect(await probe.refreshCount == 1)
}

@MainActor
@Test func studentChatSessionReusesGraphAndRefreshesBindingOncePerInvalidationWindow() async throws
{
  let userID = UUID()
  let repository = InMemoryChatRepository(currentUserID: userID, seed: .student())
  let controller = ChatSessionController()
  let probe = SuspendedBindingRefreshProbe()
  let coachID = UUID()

  await controller.activateStudent(
    repository: repository,
    currentUserID: userID,
    activeCoachID: coachID,
    refreshBinding: { await probe.refresh() }
  )
  let firstInbox = try #require(controller.context?.inbox)
  let firstCoordinator = try #require(controller.context?.sendCoordinator)

  await controller.activateStudent(
    repository: repository,
    currentUserID: userID,
    activeCoachID: coachID,
    refreshBinding: { await probe.refresh() }
  )
  #expect(controller.context?.inbox === firstInbox)
  #expect(controller.context?.sendCoordinator === firstCoordinator)

  let firstRoute = Task { await controller.reportBindingInvalidation() }
  await probe.waitUntilStarted()
  let duplicateRoute = Task { await controller.reportBindingInvalidation() }
  await Task.yield()
  await probe.release()
  await firstRoute.value
  await duplicateRoute.value

  #expect(await probe.refreshCount == 1)
}

@MainActor
@Test func bindingTransitionBlocksOldCoachGraphUntilNewContextIsPublished() async {
  let userID = UUID()
  let oldCoachID = UUID()
  let newCoachID = UUID()
  let repository = InMemoryChatRepository(currentUserID: userID, seed: .student())
  let controller = ChatSessionController()

  await controller.activateStudent(
    repository: repository,
    currentUserID: userID,
    activeCoachID: oldCoachID,
    refreshBinding: {}
  )
  #expect(controller.context != nil)

  await controller.prepareForStudentBindingChange(from: oldCoachID, to: newCoachID)
  #expect(controller.context == nil)
  #expect(!controller.canActivateStudent(for: oldCoachID))
  #expect(controller.canActivateStudent(for: newCoachID))

  await controller.activateStudent(
    repository: repository,
    currentUserID: userID,
    activeCoachID: oldCoachID,
    refreshBinding: {}
  )
  #expect(controller.context == nil)

  await controller.activateStudent(
    repository: repository,
    currentUserID: userID,
    activeCoachID: newCoachID,
    refreshBinding: {}
  )
  #expect(controller.context?.currentUserID == userID)
  #expect(!controller.isChangingStudentBinding)
}

@MainActor
@Test func sameCoachRefreshKeepsSessionCoordinatorAndInFlightWork() async throws {
  let userID = UUID()
  let coachID = UUID()
  let repository = InMemoryChatRepository(currentUserID: userID, seed: .student())
  let controller = ChatSessionController()
  await controller.activateStudent(
    repository: repository,
    currentUserID: userID,
    activeCoachID: coachID,
    refreshBinding: {}
  )
  let coordinator = try #require(controller.context?.sendCoordinator)

  await controller.prepareForStudentBindingChange(from: coachID, to: coachID)

  #expect(controller.context?.sendCoordinator === coordinator)
  #expect(!controller.isChangingStudentBinding)
}

private actor BindingRefreshProbe {
  private(set) var refreshCount = 0

  func recordRefresh() {
    refreshCount += 1
  }
}

private actor SuspendedBindingRefreshProbe {
  private(set) var refreshCount = 0
  private var startedContinuations: [CheckedContinuation<Void, Never>] = []
  private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
  private var hasStarted = false
  private var isReleased = false

  func refresh() async {
    refreshCount += 1
    hasStarted = true
    let continuations = startedContinuations
    startedContinuations.removeAll()
    for continuation in continuations {
      continuation.resume()
    }
    if !isReleased {
      await withCheckedContinuation { continuation in
        releaseContinuations.append(continuation)
      }
    }
  }

  func waitUntilStarted() async {
    guard !hasStarted else { return }
    await withCheckedContinuation { continuation in
      startedContinuations.append(continuation)
    }
  }

  func release() {
    isReleased = true
    let continuations = releaseContinuations
    releaseContinuations.removeAll()
    for continuation in continuations {
      continuation.resume()
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func lateStudentActivationCannotPublishAfterLogout() async {
  // Logout resets the per-binding flags, so those alone would let a parked
  // activation conclude it is still wanted. Only a session generation survives
  // that reset. The activation is parked inside its own teardown, which waits
  // on the previous coordinator's in-flight send.
  let userID = UUID()
  let coachA = UUID()
  let coachB = UUID()
  let controller = ChatSessionController()
  let blocking = BlockingSendRepository()

  await controller.activateStudent(
    repository: blocking,
    currentUserID: userID,
    activeCoachID: coachA,
    refreshBinding: {}
  )
  let coordinator = controller.context?.sendCoordinator
  #expect(coordinator != nil)
  coordinator?.sendText(in: UUID(), text: "占住清理", clientID: "blocker")
  #expect(await blocking.waitUntilSending())

  // Deliberately not awaiting `prepareForStudentBindingChange` here: it drains
  // too, so awaiting it inline would block on the very send this test parks.
  let activation = Task { @MainActor in
    await controller.activateStudent(
      repository: blocking,
      currentUserID: userID,
      activeCoachID: coachB,
      refreshBinding: {}
    )
  }
  // Observable signal rather than a fixed delay: the send is only cancelled once
  // a caller has entered the drain, so this proves the activation is parked there.
  #expect(await blocking.waitUntilCancelled())

  // Logout must run concurrently: it awaits the same drain the activation is
  // parked on, so releasing the send is what lets both finish. It advances the
  // generation in its first synchronous statement, so yielding until it has been
  // scheduled is enough; there is no observable signal for "generation bumped",
  // and a second caller joins the existing teardown without cancelling again.
  let logout = Task { @MainActor in await controller.cancelAllAndWaitForCleanup() }
  for _ in 0..<10 { await Task.yield() }

  await blocking.release()
  await logout.value
  await activation.value

  #expect(controller.context == nil)
  #expect(controller.activeStudentCoachID == nil)
}

/// Parks `sendText` so a coordinator has genuinely in-flight work, which makes
/// teardown — and therefore any activation that awaits it — suspend.
private actor BlockingSendRepository: ChatRepository {
  private var continuation: CheckedContinuation<Void, Never>?
  private var sending = false

  /// Set when the send task is cancelled, which only happens once a caller has
  /// entered the drain — a real signal instead of guessing with a fixed delay.
  private var cancelled = false

  func noteCancelled() { cancelled = true }

  func waitUntilCancelled() async -> Bool {
    for _ in 0..<400 {
      if cancelled { return true }
      try? await Task.sleep(for: .milliseconds(5))
    }
    return false
  }

  func waitUntilSending() async -> Bool {
    for _ in 0..<200 {
      if sending { return true }
      try? await Task.sleep(for: .milliseconds(5))
    }
    return false
  }

  func release() {
    continuation?.resume()
    continuation = nil
  }

  func fetchConversations() async throws -> [ChatConversation] { [] }

  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation {
    throw ChatRepositoryError.conversationNotFound
  }

  func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
  }

  func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) async throws -> ChatMessage {
    sending = true
    await withTaskCancellationHandler {
      await withCheckedContinuation { self.continuation = $0 }
    } onCancel: {
      Task { await self.noteCancelled() }
    }
    throw ChatRepositoryError.conversationNotFound
  }

  func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) async throws -> ChatMessage {
    throw ChatRepositoryError.conversationNotFound
  }

  func markRead(in conversationID: UUID, upTo messageID: UUID) async throws -> ChatReadState {
    throw ChatRepositoryError.conversationNotFound
  }
}
