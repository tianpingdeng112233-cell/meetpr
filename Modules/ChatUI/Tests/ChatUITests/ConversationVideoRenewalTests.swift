import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ConversationVideoRenewalTests {
  private let currentUserID = chatTestUUID(1)
  private let conversationID = chatTestUUID(20)

  @Test func playbackFailureReplacesURLUsingExactSingleMessageQuery() async throws {
    let repository = TestChatRepository()
    let targetID = chatTestUUID(40)
    let oldURL = try #require(URL(string: "https://example.test/old.mp4"))
    let newURL = try #require(URL(string: "https://example.test/new.mp4"))
    let target = try videoMessage(id: targetID, seq: 7, url: oldURL)
    let refreshed = try videoMessage(id: targetID, seq: 7, url: newURL)
    await repository.enqueuePage(
      ChatMessagePage(messages: [target], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [refreshed], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)
    await viewModel.load()

    let resolved = try await viewModel.videoPlaybackURL(
      messageID: targetID,
      forceRenewal: true
    )

    #expect(resolved == newURL)
    #expect(viewModel.message(withID: targetID)?.videoURL == newURL)
    #expect(await repository.queries.last?.mode == .before(seq: 8))
    #expect(await repository.queries.last?.limit == 1)
  }

  @Test func expiredURLRenewsBeforePlayback() async throws {
    let repository = TestChatRepository()
    let now = LockedTestNow(Date(timeIntervalSince1970: 1_700_000_000))
    let targetID = chatTestUUID(41)
    let oldURL = try #require(URL(string: "https://example.test/expired.mp4"))
    let newURL = try #require(URL(string: "https://example.test/fresh.mp4"))
    let target = try videoMessage(id: targetID, seq: 3, url: oldURL, expiresIn: 1)
    let refreshed = try videoMessage(id: targetID, seq: 3, url: newURL)
    await repository.enqueuePage(
      ChatMessagePage(messages: [target], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [refreshed], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository, now: { now() })
    await viewModel.load()
    now.advance(by: 2)

    let resolved = try await viewModel.videoPlaybackURL(messageID: targetID)

    #expect(resolved == newURL)
    #expect(await repository.queries.last?.mode == .before(seq: 4))
    #expect(await repository.queries.last?.limit == 1)
  }

  @Test func renewalTargetDisappearingDeletesLocalMessage() async throws {
    let repository = TestChatRepository()
    let targetID = chatTestUUID(42)
    let url = try #require(URL(string: "https://example.test/private.mp4"))
    let target = try videoMessage(
      id: targetID,
      seq: 9,
      senderID: chatTestUUID(2),
      url: url
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [target], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)
    await viewModel.load()

    await #expect(throws: ChatVideoPlaybackError.unavailable) {
      try await viewModel.videoPlaybackURL(
        messageID: targetID,
        forceRenewal: true
      )
    }

    #expect(viewModel.message(withID: targetID) == nil)
    #expect(viewModel.messages.isEmpty)
    #expect(await repository.queries.last?.mode == .before(seq: 10))
    #expect(await repository.queries.last?.limit == 1)
  }

  @Test func ownCardRenewalFailureKeepsMessageAndMarksVideoUnavailable() async throws {
    let repository = TestChatRepository()
    let targetID = chatTestUUID(43)
    let url = try #require(URL(string: "https://example.test/own.mp4"))
    let target = try videoMessage(id: targetID, seq: 10, url: url)
    await repository.enqueuePage(
      ChatMessagePage(messages: [target], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)
    await viewModel.load()

    await #expect(throws: ChatVideoPlaybackError.unavailable) {
      try await viewModel.videoPlaybackURL(
        messageID: targetID,
        forceRenewal: true
      )
    }

    let retained = try #require(viewModel.message(withID: targetID))
    #expect(retained.senderID == currentUserID)
    #expect(retained.setRef != nil)
    #expect(retained.text == target.text)
    #expect(retained.videoURL == nil)
    #expect(retained.videoExpiresIn == nil)
  }

  @Test func staleLoadCannotResurrectMessageDeletedDuringRenewal() async throws {
    let repository = TestChatRepository()
    let targetID = chatTestUUID(44)
    let url = try #require(URL(string: "https://example.test/other.mp4"))
    let target = try videoMessage(
      id: targetID,
      seq: 11,
      senderID: chatTestUUID(2),
      url: url
    )
    let newer = chatTestMessage(
      id: chatTestUUID(45),
      conversationID: conversationID,
      seq: 12,
      senderID: currentUserID,
      clientID: "newer",
      text: "更新消息"
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [target, newer], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)
    await viewModel.load()

    // A suspended poll would be contract-dishonest here: .after(maxSeq) can never return an
    // older seq. A concurrent .latest load legitimately can — that is the real stale carrier.
    await repository.suspendNextFetch()
    let refresh = Task { await viewModel.load() }
    #expect(await chatEventually { await repository.hasPendingFetch() })

    await #expect(throws: ChatVideoPlaybackError.unavailable) {
      try await viewModel.videoPlaybackURL(
        messageID: targetID,
        forceRenewal: true
      )
    }
    #expect(viewModel.message(withID: targetID) == nil)

    await repository.resolvePendingFetch(
      with: ChatMessagePage(messages: [target, newer], otherLastRead: nil, hasMore: false)
    )
    await refresh.value

    #expect(viewModel.message(withID: targetID) == nil)
    #expect(viewModel.messages.map(\.id) == [newer.id])
  }

  private func makeViewModel(
    repository: TestChatRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) -> ConversationViewModel {
    ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: ChatSendCoordinator(
        repository: repository,
        currentUserID: currentUserID
      ),
      now: now
    )
  }

  private func videoMessage(
    id: UUID,
    seq: Int,
    senderID: UUID? = nil,
    url: URL,
    expiresIn: Int = 900
  ) throws -> ChatMessage {
    let setRef = try SetRefV1(
      source: .logged,
      exerciseName: "暂停深蹲",
      setNumber: 1,
      setTotal: 3,
      weightKg: "125",
      reps: 5,
      repsMax: nil,
      rpe: "8",
      dayDate: "2026-07-27",
      setLogId: chatTestUUID(50),
      planSetId: nil
    )
    return chatTestMessage(
      id: id,
      conversationID: conversationID,
      seq: seq,
      senderID: senderID ?? currentUserID,
      clientID: "video-\(seq)",
      text: SetRefCanonicalFormatter.firstLine(for: setRef),
      setRef: setRef,
      videoURL: url,
      videoExpiresIn: expiresIn
    )
  }
}
