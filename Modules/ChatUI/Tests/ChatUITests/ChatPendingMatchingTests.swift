import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ChatPendingMatchingTests {
  @Test func opponentUsingSameClientIDDoesNotReconcileCurrentUsersPendingItem() async {
    let currentUserID = chatTestUUID(1)
    let conversationID = chatTestUUID(50)
    let repository = TestChatRepository()
    await repository.suspendTextSends()
    let opponentMessage = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: chatTestUUID(2),
      clientID: "shared-client-id"
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [opponentMessage], otherLastRead: nil, hasMore: false)
    )
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )
    coordinator.sendText(
      in: conversationID,
      text: "我的消息",
      clientID: "shared-client-id"
    )
    _ = await chatEventually {
      await repository.pendingTextClientIDs().contains("shared-client-id")
    }

    await viewModel.pollOnce()

    #expect(viewModel.messages.map(\.id) == [opponentMessage.id])
    #expect(viewModel.pending.map(\.clientID) == ["shared-client-id"])

    let ownMessage = chatTestMessage(
      conversationID: conversationID,
      seq: 2,
      senderID: currentUserID,
      clientID: "shared-client-id"
    )
    await repository.resolveText(clientID: "shared-client-id", with: .success(ownMessage))
    _ = await chatEventually {
      await MainActor.run { coordinator.outbox(in: conversationID).isEmpty }
    }
  }
}
