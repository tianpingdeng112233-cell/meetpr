import ChatUI
import CoreModels
import Foundation
import Networking
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func activationWithoutRealtimeFactoryProducesNoClient() async throws {
  let userID = UUID()
  let repository = InMemoryChatRepository(currentUserID: userID, seed: .coach())
  let controller = ChatSessionController()

  await controller.activateCoach(repository: repository, currentUserID: userID)

  #expect(try #require(controller.context).realtimeClient == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func backgroundIntentRecordedBeforeActivationBlocksConnect() async throws {
  let userID = UUID()
  let repository = InMemoryChatRepository(currentUserID: userID, seed: .coach())
  let controller = ChatSessionController()
  controller.configureRealtime(factory: {
    RealtimeClient(
      baseURL: URL(string: "http://127.0.0.1:9") ?? URL(filePath: "/invalid"),
      session: LifecycleSessionStub()
    )
  })

  // Background arrives while no context exists yet; the intent must survive
  // until the activation finishes and gate its connect.
  controller.noteScenePhase(isActive: false)
  await controller.activateCoach(repository: repository, currentUserID: userID)
  let client = try #require(controller.context?.realtimeClient)

  for _ in 0..<50 { await Task.yield() }
  #expect(await client.isConnectionDesired() == false)

  controller.noteScenePhase(isActive: true)
  #expect(await lifecycleEventually { await client.isConnectionDesired() })

  await client.disconnect()
}

private struct LifecycleSessionStub: SessionStateReader {
  func accessToken() async throws -> String { "lifecycle-test-token" }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private func lifecycleEventually(
  _ condition: @Sendable () async -> Bool
) async -> Bool {
  for _ in 0..<200 {
    if await condition() { return true }
    await Task.yield()
    try? await Task.sleep(for: .milliseconds(5))
  }
  return await condition()
}
