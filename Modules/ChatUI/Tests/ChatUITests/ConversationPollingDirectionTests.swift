import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

/// Polling direction: `.latest` bootstraps and reports *older* history via
/// hasMore; only `.after` drives forward catch-up.
@Suite @MainActor struct ConversationPollingDirectionTests {
  private let currentUserID = chatTestUUID(1)
  private let conversationID = chatTestUUID(10)

  @Test func oneTickCatchesUpMoreThanTwoPages() async {
    // Catch-up only applies once we hold a maximum seq. A `.latest` page is the
    // *newest* slice and its hasMore means older history exists, so seeding the
    // backlog through `.latest` would model a contract the backend never has.
    let repository = TestChatRepository()
    await repository.enqueuePage(
      ChatMessagePage(
        messages: [
          chatTestMessage(
            conversationID: conversationID,
            seq: 1,
            senderID: currentUserID,
            clientID: "page-1"
          )
        ],
        otherLastRead: nil,
        hasMore: false
      )
    )
    for sequence in 2...4 {
      await repository.enqueuePage(
        ChatMessagePage(
          messages: [
            chatTestMessage(
              conversationID: conversationID,
              seq: sequence,
              senderID: currentUserID,
              clientID: "page-\(sequence)"
            )
          ],
          otherLastRead: nil,
          hasMore: sequence < 4
        )
      )
    }
    let viewModel = makeViewModel(repository: repository)

    await viewModel.pollOnce()  // bootstraps from latest
    await viewModel.pollOnce()  // three-page backlog drained in this one tick

    #expect(viewModel.messages.map(\.seq) == [1, 2, 3, 4])
    #expect(
      await repository.queries.map(\.mode) == [
        .latest,
        .after(seq: 1),
        .after(seq: 2),
        .after(seq: 3),
      ])
  }

  private func makeViewModel(repository: TestChatRepository) -> ConversationViewModel {
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    return ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )
  }
}
