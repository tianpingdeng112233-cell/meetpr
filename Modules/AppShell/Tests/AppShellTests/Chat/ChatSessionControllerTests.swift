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

private actor BindingRefreshProbe {
  private(set) var refreshCount = 0

  func recordRefresh() {
    refreshCount += 1
  }
}
