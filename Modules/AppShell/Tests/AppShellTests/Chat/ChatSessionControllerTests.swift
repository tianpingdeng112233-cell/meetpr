import ChatUI
import Foundation
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
