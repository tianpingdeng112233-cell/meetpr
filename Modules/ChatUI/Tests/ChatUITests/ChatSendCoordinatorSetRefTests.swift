import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import ChatUI

// swiftlint:disable type_body_length
@Suite @MainActor struct ChatSendCoordinatorSetRefTests {
  private let currentUserID = chatTestUUID(1)
  private let conversationID = chatTestUUID(10)

  @Test func intentFreezesSnapshotAndRepeatedTriggerUsesOneClientID() async throws {
    let repository = TestChatRepository()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    var sourceWeight = "100.00"
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: setRefSource(weightKg: sourceWeight),
      note: "看看深度"
    )
    sourceWeight = "120.00"

    let firstClientID = coordinator.sendSetRef(intent)
    let secondClientID = coordinator.sendSetRef(intent)
    let didSend = await chatEventually { await repository.setRefClientIDs.count == 1 }

    #expect(didSend)
    #expect(firstClientID == intent.clientID)
    #expect(secondClientID == intent.clientID)
    #expect(await repository.setRefClientIDs == [intent.clientID])
    #expect(await repository.sentSetRefs.first?.weightKg == "100")
    #expect(
      await repository.setRefBodies.first
        == "[训练分享] 低杠位深蹲 第3组/5 100kg×5 @RPE8 (2026-07-27)\n看看深度"
    )
    #expect(sourceWeight == "120.00")
    #expect(await repository.imageClientIDs.isEmpty)
  }

  @Test func stagedIntentKeepsFrozenClientIDWhenComposerAddsNote() async throws {
    let repository = TestChatRepository()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: setRefSource(),
      note: nil
    )
    coordinator.stageSetRef(intent)
    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )

    #expect(viewModel.stagedSetRef?.clientID == intent.clientID)
    #expect(viewModel.sendStagedSetRef(note: "  看看深度  ") == intent.clientID)
    #expect(viewModel.stagedSetRef.map { _ in false } ?? true)
    let didSend = await chatEventually { await repository.setRefClientIDs.count == 1 }

    #expect(didSend)
    #expect(await repository.setRefClientIDs == [intent.clientID])
    #expect(
      await repository.setRefBodies.first
        == "[训练分享] 低杠位深蹲 第3组/5 100kg×5 @RPE8 (2026-07-27)\n看看深度"
    )
  }

  @Test func stagedUploadingVideoCanSendBeforeUploadIsReady() async throws {
    let repository = TestChatRepository()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    let localAttachmentID = chatTestUUID(30)
    let remoteVideoID = chatTestUUID(31)
    let eventSource = AsyncStream.makeStream(
      of: SetRefVideoUploadEvent.self,
      bufferingPolicy: .bufferingNewest(8)
    )
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: setRefSource(),
      note: nil,
      video: .uploading(
        localAttachmentID: localAttachmentID,
        events: eventSource.stream
      )
    )
    coordinator.stageSetRef(intent)
    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )

    #expect(viewModel.sendStagedSetRef(note: "") == intent.clientID)
    #expect(coordinator.outbox(in: conversationID).count == 1)
    await Task.yield()
    #expect(await repository.setRefClientIDs.isEmpty)

    eventSource.continuation.yield(
      .ready(localAttachmentID: localAttachmentID, videoID: remoteVideoID)
    )
    let didSend = await chatEventually { await repository.setRefClientIDs.count == 1 }
    #expect(didSend)
    eventSource.continuation.finish()
  }

  @Test func logoutDropsUnsentStagedIntent() async throws {
    let coordinator = ChatSendCoordinator(
      repository: TestChatRepository(),
      currentUserID: currentUserID
    )
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: setRefSource(),
      note: nil
    )
    coordinator.stageSetRef(intent)

    await coordinator.cancelAllAndWaitForCleanup()

    #expect(coordinator.stagedSetRef(in: conversationID).map { _ in false } ?? true)
  }

  @Test func failedRetryReusesClientIDAndNeverEntersImageCleanupPath() async throws {
    let responder = SetRefNetworkResponder(messageStatusCodes: [500, 201])
    let coordinator = makeNetworkCoordinator(responder: responder)
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: setRefSource(),
      note: nil,
      video: .ready(videoID: chatTestUUID(31))
    )

    coordinator.sendSetRef(intent)
    let didFail = await chatEventually {
      guard let item = coordinator.outbox(in: self.conversationID).first else {
        return false
      }
      if case .failed = item.state { return true }
      return false
    }
    #expect(didFail)
    #expect(await responder.requestMethods() == ["POST"])

    coordinator.retry(in: conversationID, clientID: intent.clientID)
    let didRetry = await chatEventually {
      guard let item = coordinator.outbox(in: self.conversationID).first else {
        return false
      }
      if case .confirmed = item.state { return true }
      return false
    }

    #expect(didRetry)
    #expect(await responder.requestMethods() == ["POST", "POST"])
  }

  @Test func uploadSurvivesSheetDismissAndReadyAutomaticallySends() async throws {
    let responder = SetRefNetworkResponder()
    let coordinator = makeNetworkCoordinator(responder: responder)
    let localAttachmentID = chatTestUUID(30)
    let remoteVideoID = chatTestUUID(31)
    let eventSource = AsyncStream.makeStream(
      of: SetRefVideoUploadEvent.self,
      bufferingPolicy: .bufferingNewest(8)
    )
    weak var dismissedSheetOwner: SetRefSheetOwner?
    do {
      let sheetOwner = SetRefSheetOwner(
        intent: try coordinator.makeSetRefIntent(
          in: conversationID,
          source: setRefSource(),
          note: "上传后自动发",
          video: .uploading(
            localAttachmentID: localAttachmentID,
            events: eventSource.stream
          )
        )
      )
      dismissedSheetOwner = sheetOwner
      coordinator.sendSetRef(sheetOwner.intent)
    }
    #expect(dismissedSheetOwner == nil)
    await Task.yield()
    #expect(await responder.requestMethods().isEmpty)

    eventSource.continuation.yield(
      .ready(localAttachmentID: localAttachmentID, videoID: remoteVideoID)
    )
    let didSend = await chatEventually {
      guard let item = coordinator.outbox(in: self.conversationID).first else {
        return false
      }
      if case .confirmed = item.state { return true }
      return false
    }

    #expect(didSend)
    #expect(await responder.requestMethods() == ["POST"])
    eventSource.continuation.finish()
  }

  @Test func logoutCancelsWaitingIntentWithoutImageCleanup() async throws {
    let responder = SetRefNetworkResponder()
    let coordinator = makeNetworkCoordinator(responder: responder)
    let terminationRecorder = SetRefStreamTerminationRecorder()
    let eventSource = AsyncStream.makeStream(
      of: SetRefVideoUploadEvent.self,
      bufferingPolicy: .bufferingNewest(8)
    )
    eventSource.continuation.onTermination = { termination in
      if case .cancelled = termination {
        terminationRecorder.recordCancellation()
      }
    }
    let localAttachmentID = chatTestUUID(30)
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: setRefSource(),
      note: nil,
      video: .uploading(
        localAttachmentID: localAttachmentID,
        events: eventSource.stream
      )
    )
    coordinator.sendSetRef(intent)
    await Task.yield()

    await coordinator.cancelAllAndWaitForCleanup()

    #expect(coordinator.outbox(in: conversationID).isEmpty)
    let didCancelSubscription = await chatEventually {
      terminationRecorder.wasCancelled
    }
    #expect(didCancelSubscription)
    eventSource.continuation.yield(
      .ready(localAttachmentID: localAttachmentID, videoID: chatTestUUID(31))
    )
    try await Task.sleep(for: .milliseconds(10))
    #expect(await responder.requestMethods().isEmpty)
    eventSource.continuation.finish()
  }

  @Test func successfulSetRefWithReadyVideoNeverEntersImageCleanupPath() async throws {
    let responder = SetRefNetworkResponder()
    let coordinator = makeNetworkCoordinator(responder: responder)
    let videoID = chatTestUUID(31)
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: setRefSource(),
      note: nil,
      video: .ready(videoID: videoID)
    )

    coordinator.sendSetRef(intent)
    let didSend = await chatEventually {
      guard let item = coordinator.outbox(in: self.conversationID).first else {
        return false
      }
      if case .confirmed = item.state { return true }
      return false
    }

    #expect(didSend)
    #expect(await responder.requestMethods() == ["POST"])
  }

  private func makeNetworkCoordinator(
    responder: SetRefNetworkResponder
  ) -> ChatSendCoordinator {
    let client = APIClient(
      environment: ["MEETPR_API_BASE_URL": "https://api.test"]
    ) { request in
      await responder.respond(to: request)
    }
    let repository = NetworkChatRepository(
      apiClient: client,
      session: SetRefNetworkSessionStub(),
      uploader: OSSPartUploader()
    )
    return ChatSendCoordinator(repository: repository, currentUserID: currentUserID)
  }

  private func setRefSource(weightKg: String = "100.00") -> SetRefSourceSnapshot {
    SetRefSourceSnapshot(
      source: .logged,
      exerciseName: "低杠位深蹲",
      setNumber: 3,
      setTotal: 5,
      weightKg: weightKg,
      reps: 5,
      repsMax: nil,
      rpe: "8.0",
      dayDate: "2026-07-27",
      setLogId: chatTestUUID(20),
      planSetId: nil
    )
  }
}
// swiftlint:enable type_body_length

private final class SetRefSheetOwner {
  let intent: SetRefSendIntent

  init(intent: SetRefSendIntent) {
    self.intent = intent
  }
}

private struct SetRefNetworkSessionStub: SessionStateReader {
  func accessToken() async throws -> String {
    "chat-token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private actor SetRefNetworkResponder {
  private var capturedRequests: [URLRequest] = []
  private var messageStatusCodes: [Int]

  init(messageStatusCodes: [Int] = [201]) {
    self.messageStatusCodes = messageStatusCodes
  }

  func respond(to request: URLRequest) -> APIResponse {
    capturedRequests.append(request)
    if request.httpMethod == "DELETE" {
      return APIResponse(data: Data(), statusCode: 204)
    }

    let statusCode =
      messageStatusCodes.isEmpty
      ? 201
      : messageStatusCodes.removeFirst()
    guard (200..<300).contains(statusCode) else {
      return APIResponse(
        data: Data(#"{"error":"SET_REF_TEST_FAILURE"}"#.utf8),
        statusCode: statusCode
      )
    }
    return APIResponse(data: setRefNetworkMessageResponse(), statusCode: statusCode)
  }

  func requestMethods() -> [String] {
    capturedRequests.map { $0.httpMethod ?? "UNKNOWN" }
  }
}

private final class SetRefStreamTerminationRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false

  var wasCancelled: Bool {
    lock.withLock { cancelled }
  }

  func recordCancellation() {
    lock.withLock {
      cancelled = true
    }
  }
}

private func setRefNetworkMessageResponse() -> Data {
  Data(
    """
    {
      "message": {
        "id": "\(chatTestUUID(40).uuidString)",
        "conversation_id": "\(chatTestUUID(10).uuidString)",
        "seq": 1,
        "sender_id": "\(chatTestUUID(1).uuidString)",
        "kind": "text",
        "body": "训练分享",
        "attachment_id": null,
        "image_url": null,
        "image_expires_in": null,
        "client_id": "network-set-ref",
        "created_at": "2026-07-27T12:00:00.000Z"
      }
    }
    """.utf8
  )
}
