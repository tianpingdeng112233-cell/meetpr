import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ConversationImageRenewalTests {
  private let currentUserID = chatTestUUID(1)
  private let conversationID = chatTestUUID(20)

  @Test func expiredImageOutsideLatestPageRenewsInPlaceWithBeforeQuery() async throws {
    let repository = TestChatRepository()
    let now = LockedTestNow(Date(timeIntervalSince1970: 1_700_000_000))
    let targetID = chatTestUUID(30)
    let oldURL = try #require(URL(string: "https://example.com/old.jpg"))
    let newURL = try #require(URL(string: "https://example.com/new.jpg"))
    let target = imageMessage(id: targetID, seq: 1, url: oldURL, expiresIn: 1)
    let newer = chatTestMessage(
      conversationID: conversationID,
      seq: 2,
      senderID: currentUserID,
      clientID: "newer"
    )
    let refreshed = imageMessage(id: targetID, seq: 1, url: newURL, expiresIn: 900)
    await repository.enqueuePage(
      ChatMessagePage(messages: [target], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [newer], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [refreshed], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository, now: { now() })
    await viewModel.load()
    await viewModel.pollOnce()
    now.advance(by: 2)

    await viewModel.refreshImageIfNeeded(messageID: targetID)

    #expect(viewModel.messages.count == 2)
    #expect(viewModel.message(withID: targetID)?.imageURL == newURL)
    #expect(await repository.queries.last?.mode == .before(seq: 2))
  }

  @Test func imageLoadFailureForcesExactlyOneRenewalWithoutExpiry() async throws {
    let repository = TestChatRepository()
    let now = LockedTestNow(Date(timeIntervalSince1970: 1_700_000_000))
    let targetID = chatTestUUID(31)
    let oldURL = try #require(URL(string: "https://example.com/valid.jpg"))
    let newURL = try #require(URL(string: "https://example.com/resigned.jpg"))
    let target = imageMessage(id: targetID, seq: 5, url: oldURL, expiresIn: 900)
    let refreshed = imageMessage(id: targetID, seq: 5, url: newURL, expiresIn: 900)
    await repository.enqueuePage(
      ChatMessagePage(messages: [target], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [refreshed], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository, now: { now() })
    await viewModel.load()

    await viewModel.imageLoadingFailed(messageID: targetID)
    await viewModel.imageLoadingFailed(messageID: targetID)

    #expect(viewModel.message(withID: targetID)?.imageURL == newURL)
    #expect(await repository.queries.count == 2)
    #expect(await repository.queries.last?.mode == .before(seq: 6))
  }

  @Test func nilImageURLShowsPlaceholderWithoutRenewalRequest() async {
    let repository = TestChatRepository()
    let targetID = chatTestUUID(32)
    let target = imageMessage(id: targetID, seq: 1, url: nil, expiresIn: 900)
    await repository.enqueuePage(
      ChatMessagePage(messages: [target], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)
    await viewModel.load()

    await viewModel.imageLoadingFailed(messageID: targetID)
    await viewModel.refreshImageIfNeeded(messageID: targetID)

    #expect(await repository.queries.count == 1)
    #expect(viewModel.message(withID: targetID)?.imageURL == nil)
  }

  private func makeViewModel(
    repository: TestChatRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) -> ConversationViewModel {
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    return ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator,
      now: now
    )
  }

  private func imageMessage(
    id: UUID,
    seq: Int,
    url: URL?,
    expiresIn: Int
  ) -> ChatMessage {
    chatTestMessage(
      id: id,
      conversationID: conversationID,
      seq: seq,
      senderID: currentUserID,
      clientID: "image",
      kind: .image,
      imageURL: url,
      imageExpiresIn: expiresIn
    )
  }
}
