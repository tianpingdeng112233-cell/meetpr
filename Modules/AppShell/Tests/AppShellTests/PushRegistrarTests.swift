import CoreModels
import Foundation
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func staleUploadFromPreviousSessionAlwaysLandsBeforeTheCurrentOnes() async {
  let uploader = PushUploadRecorder()
  let registrar = PushRegistrar(
    authorizationStatusProvider: { .allowed },
    authorizationRequester: { true },
    remoteRegistration: {},
    accessTokenProvider: { "access" },
    tokenUploader: { token, _ in await uploader.perform(token) }
  )

  registrar.authenticatedRootDidAppear()
  await uploader.suspendNext()
  registrar.receivedDeviceToken("aaaa")
  #expect(await pushEventually { await uploader.started == ["aaaa"] })

  // User A logs out while the upload is still in flight; user B logs in and
  // reports the same device. B's upload must queue behind A's so the server's
  // last write re-attributes the token to B, never back to A.
  registrar.authenticatedSessionDidEnd()
  registrar.authenticatedRootDidAppear()
  registrar.receivedDeviceToken("bbbb")
  for _ in 0..<20 { await Task.yield() }
  #expect(await uploader.started == ["aaaa"])

  await uploader.releaseSuspended()
  #expect(await pushEventually { await uploader.completed == ["aaaa", "bbbb"] })
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func pendingRouteIsOverwrittenByNewerPushesAndConsumedExactlyOnce() {
  let registrar = PushRegistrar(
    authorizationStatusProvider: { .allowed },
    authorizationRequester: { true },
    remoteRegistration: {},
    accessTokenProvider: { "access" },
    tokenUploader: { _, _ in }
  )
  let conversationID = UUID()
  let requestID = UUID()

  registrar.receiveNotificationPayload(
    PushPayloadValues(kind: "chat_message", conversationID: conversationID.uuidString)
  )
  let staleRoute = PushRouteIntent.chatMessage(conversationID: conversationID)
  #expect(registrar.pendingRoute == staleRoute)

  registrar.receiveNotificationPayload(
    PushPayloadValues(kind: "bind_request", requestID: requestID.uuidString)
  )
  let newerRoute = PushRouteIntent.bindRequest(requestID: requestID)
  #expect(registrar.pendingRoute == newerRoute)

  // A consumer holding the stale route must not clear the newer one.
  registrar.consumePendingRoute(staleRoute)
  #expect(registrar.pendingRoute == newerRoute)

  registrar.consumePendingRoute(newerRoute)
  #expect(registrar.pendingRoute == nil)

  // Consuming again is a no-op, not a crash or a resurrection.
  registrar.consumePendingRoute(newerRoute)
  #expect(registrar.pendingRoute == nil)
}

private actor PushUploadRecorder {
  private(set) var started: [String] = []
  private(set) var completed: [String] = []
  private var suspendNextUpload = false
  private var waiter: CheckedContinuation<Void, Never>?

  func suspendNext() {
    suspendNextUpload = true
  }

  func releaseSuspended() {
    waiter?.resume()
    waiter = nil
  }

  func perform(_ token: String) async {
    started.append(token)
    if suspendNextUpload {
      suspendNextUpload = false
      await withCheckedContinuation { waiter = $0 }
    }
    completed.append(token)
  }
}

private func pushEventually(
  _ condition: @Sendable () async -> Bool
) async -> Bool {
  for _ in 0..<200 {
    if await condition() { return true }
    await Task.yield()
    try? await Task.sleep(for: .milliseconds(5))
  }
  return await condition()
}
