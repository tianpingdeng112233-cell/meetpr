import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Test func inMemoryOpenConversationIsIdempotent() async throws {
  let currentUserID = testUUID(1)
  let otherUserID = testUUID(2)
  let repository = InMemoryChatRepository(
    currentUserID: currentUserID,
    seed: ChatDemoSeed(
      conversations: [],
      messagesByConversationID: [:],
      otherPartyNames: [otherUserID: "王晨曦"]
    )
  )

  let first = try await repository.openConversation(withOtherParty: otherUserID)
  let second = try await repository.openConversation(withOtherParty: otherUserID)

  #expect(first.id == second.id)
  #expect(first.otherPartyName == "王晨曦")
  #expect(try await repository.fetchConversations().count == 1)
}

@Test func inMemorySendAppendsAndUpdatesConversation() async throws {
  let fixture = chatFixture()
  let repository = InMemoryChatRepository(currentUserID: fixture.currentUserID, seed: fixture.seed)

  let sent = try await repository.sendText(
    in: fixture.conversationID,
    text: "明天加重量",
    clientID: "cli-new"
  )
  let duplicate = try await repository.sendText(
    in: fixture.conversationID,
    text: "不同内容也应命中幂等",
    clientID: "cli-new"
  )
  let page = try await repository.fetchMessages(
    in: fixture.conversationID,
    query: ChatMessageQuery.latest(limit: 30)
  )
  let conversation = try #require(
    try await repository.fetchConversations().first(where: { $0.id == fixture.conversationID })
  )

  #expect(sent.id == duplicate.id)
  #expect(sent.seq == 3)
  #expect(page.messages.count == 3)
  #expect(conversation.lastMessagePreview == "明天加重量")
  #expect(conversation.lastMessageAt == sent.createdAt)
}

@Test func inMemoryMarkReadIsMonotonic() async throws {
  let fixture = chatFixture()
  let repository = InMemoryChatRepository(currentUserID: fixture.currentUserID, seed: fixture.seed)

  let newer = try await repository.markRead(
    in: fixture.conversationID,
    upTo: fixture.incomingMessageID
  )
  let older = try await repository.markRead(
    in: fixture.conversationID,
    upTo: fixture.outgoingMessageID
  )

  #expect(newer.myLastRead.seq == 2)
  #expect(newer.unreadCount == 0)
  #expect(older == newer)
}

@Test func inMemoryUnreadAggregationUsesCurrentUserPerspective() async throws {
  let fixture = chatFixture()
  let currentUserRepository = InMemoryChatRepository(
    currentUserID: fixture.currentUserID,
    seed: fixture.seed
  )
  let otherUserRepository = InMemoryChatRepository(
    currentUserID: fixture.otherUserID,
    seed: fixture.seed
  )

  let currentView = try #require(try await currentUserRepository.fetchConversations().first)
  let otherView = try #require(try await otherUserRepository.fetchConversations().first)

  #expect(currentView.unreadCount == 1)
  #expect(otherView.unreadCount == 1)
}

private struct ChatFixture {
  let currentUserID: UUID
  let otherUserID: UUID
  let conversationID: UUID
  let outgoingMessageID: UUID
  let incomingMessageID: UUID
  let seed: ChatDemoSeed
}

private func chatFixture() -> ChatFixture {
  let ids = ChatFixtureIDs(
    currentUserID: testUUID(10),
    otherUserID: testUUID(11),
    conversationID: testUUID(12),
    outgoingMessageID: testUUID(13),
    incomingMessageID: testUUID(14)
  )
  let messages = chatFixtureMessages(ids: ids)
  let conversation = ChatConversation(
    id: ids.conversationID,
    otherPartyID: ids.otherUserID,
    otherPartyName: "对方",
    lastMessagePreview: messages.incoming.text,
    lastMessageAt: messages.incoming.createdAt,
    unreadCount: 99,
    myLastRead: nil,
    otherLastRead: nil
  )
  return ChatFixture(
    currentUserID: ids.currentUserID,
    otherUserID: ids.otherUserID,
    conversationID: ids.conversationID,
    outgoingMessageID: ids.outgoingMessageID,
    incomingMessageID: ids.incomingMessageID,
    seed: ChatDemoSeed(
      conversations: [conversation],
      messagesByConversationID: [
        ids.conversationID: [messages.outgoing, messages.incoming]
      ]
    )
  )
}

private struct ChatFixtureIDs {
  let currentUserID: UUID
  let otherUserID: UUID
  let conversationID: UUID
  let outgoingMessageID: UUID
  let incomingMessageID: UUID
}

private struct ChatFixtureMessages {
  let outgoing: ChatMessage
  let incoming: ChatMessage
}

private func chatFixtureMessages(ids: ChatFixtureIDs) -> ChatFixtureMessages {
  let firstDate = Date(timeIntervalSince1970: 1_768_900_000)
  let secondDate = Date(timeIntervalSince1970: 1_768_900_100)
  let outgoing = ChatMessage(
    id: ids.outgoingMessageID,
    conversationID: ids.conversationID,
    seq: 1,
    senderID: ids.currentUserID,
    kind: .text,
    text: "我发出的消息",
    attachmentID: nil,
    imageURL: nil,
    imageExpiresIn: nil,
    clientID: "cli-outgoing",
    createdAt: firstDate
  )
  let incoming = ChatMessage(
    id: ids.incomingMessageID,
    conversationID: ids.conversationID,
    seq: 2,
    senderID: ids.otherUserID,
    kind: .text,
    text: "对方发来的消息",
    attachmentID: nil,
    imageURL: nil,
    imageExpiresIn: nil,
    clientID: "cli-incoming",
    createdAt: secondDate
  )
  return ChatFixtureMessages(outgoing: outgoing, incoming: incoming)
}

private func testUUID(_ suffix: UInt8) -> UUID {
  UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x59, suffix))
}
