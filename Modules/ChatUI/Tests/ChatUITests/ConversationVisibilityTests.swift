import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@MainActor @Test func hiddenConversationDoesNotMarkIncomingMessagesRead() async {
  let repository = TestChatRepository()
  let conversation = chatTestUUID(20)
  let user = chatTestUUID(1)
  let message = chatTestMessage(
    conversationID: conversation, seq: 1,
    senderID: chatTestUUID(2), clientID: "hidden")
  await repository.enqueuePage(
    ChatMessagePage(messages: [message], otherLastRead: nil, hasMore: false))
  let model = ConversationViewModel(
    conversationID: conversation, currentUserID: user,
    repository: repository,
    sendCoordinator: ChatSendCoordinator(repository: repository, currentUserID: user))
  model.isReadingActive = false
  await model.pollOnce()
  #expect(await repository.readMessageIDs.isEmpty)
  await repository.enqueuePage(
    ChatMessagePage(messages: [message], otherLastRead: nil, hasMore: false))
  model.isReadingActive = true
  await model.load()
  #expect(await repository.readMessageIDs == [message.id])
}
