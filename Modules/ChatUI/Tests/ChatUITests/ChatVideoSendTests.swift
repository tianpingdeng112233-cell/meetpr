import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ChatVideoSendTests {
  @Test func failedVideoKeepsFileAndRetriesSameClientIDUntilConfirmed() async throws {
    let repository = VideoSendRepository()
    let coordinator = ChatSendCoordinator(repository: repository, currentUserID: chatTestUUID(1))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".mp4")
    try Data([1, 2, 3]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let video = ChatVideoFile(fileURL: url, contentType: "video/mp4", byteCount: 3)
    let conversationID = chatTestUUID(2)
    coordinator.sendVideo(in: conversationID, video: video, clientID: "same-video")
    let failed = await chatEventually {
      await MainActor.run {
        if case .failed = coordinator.outbox(in: conversationID).first?.state { return true }
        return false
      }
    }
    #expect(failed)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(coordinator.outbox(in: conversationID).first?.uploadProgress == 0.5)
    coordinator.retry(in: conversationID, clientID: "same-video")
    let confirmed = await chatEventually {
      await MainActor.run {
        if case .confirmed = coordinator.outbox(in: conversationID).first?.state { return true }
        return false
      }
    }
    #expect(confirmed)
    #expect(await repository.clientIDs == ["same-video", "same-video"])
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

  @Test func logoutRemovesFailedVideoFileAndOutbox() async throws {
    let repository = VideoSendRepository()
    let coordinator = ChatSendCoordinator(repository: repository, currentUserID: chatTestUUID(1))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".mov")
    try Data([1]).write(to: url)
    let conversationID = chatTestUUID(2)
    coordinator.sendVideo(
      in: conversationID,
      video: ChatVideoFile(fileURL: url, contentType: "video/quicktime", byteCount: 1),
      clientID: "logout-video")
    _ = await chatEventually {
      await MainActor.run {
        if case .failed = coordinator.outbox(in: conversationID).first?.state { return true }
        return false
      }
    }
    await coordinator.cancelAllAndWaitForCleanup()
    #expect(coordinator.outbox(in: conversationID).isEmpty)
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }
}

private actor VideoSendRepository: ChatRepository {
  var clientIDs: [String] = []
  func sendVideo(
    in conversationID: UUID, video: ChatVideoFile, clientID: String,
    progress: @escaping @Sendable (Double) async -> Void
  ) async throws -> ChatMessage {
    clientIDs.append(clientID)
    await progress(0.5)
    if clientIDs.count == 1 { throw ChatTestError.failed }
    await progress(1)
    return chatTestMessage(
      conversationID: conversationID, seq: 1, senderID: chatTestUUID(1), clientID: clientID)
  }
  func fetchConversations() async throws -> [ChatConversation] { [] }
  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation {
    throw ChatTestError.failed
  }
  func fetchMessages(in conversationID: UUID, query: ChatMessageQuery) async throws
    -> ChatMessagePage
  { .init(messages: [], otherLastRead: nil, hasMore: false) }
  func sendText(in conversationID: UUID, text: String, clientID: String) async throws -> ChatMessage
  { throw ChatTestError.failed }
  func sendImage(in conversationID: UUID, imageData: Data, clientID: String) async throws
    -> ChatMessage
  { throw ChatTestError.failed }
  func markRead(in conversationID: UUID, upTo messageID: UUID) async throws -> ChatReadState {
    throw ChatTestError.failed
  }
}

@Test @MainActor func standaloneVideoWithMissingURLCanRenewFromItsMessage() async throws {
  let repository = TestChatRepository()
  let conversation = chatTestUUID(20)
  let user = chatTestUUID(1)
  let messageID = chatTestUUID(40)
  let expectedURL = try #require(URL(string: "https://example.test/video.mp4"))
  func message(url: URL?) -> ChatMessage {
    ChatMessage(
      id: messageID, conversationID: conversation, seq: 7, senderID: user,
      kind: .text, text: "[视频]", attachmentID: nil, imageURL: nil, imageExpiresIn: nil,
      videoID: chatTestUUID(50), videoURL: url, videoExpiresIn: 900,
      clientID: "independent-video", createdAt: Date())
  }
  await repository.enqueuePage(
    .init(messages: [message(url: nil)], otherLastRead: nil, hasMore: false))
  await repository.enqueuePage(
    .init(messages: [message(url: expectedURL)], otherLastRead: nil, hasMore: false))
  let model = ConversationViewModel(
    conversationID: conversation, currentUserID: user,
    repository: repository,
    sendCoordinator: ChatSendCoordinator(repository: repository, currentUserID: user))
  await model.load()
  let url = try await model.videoPlaybackURL(messageID: messageID)
  #expect(url == expectedURL)
  #expect(await repository.queries.last == (try ChatMessageQuery.before(seq: 8, limit: 1)))
}
