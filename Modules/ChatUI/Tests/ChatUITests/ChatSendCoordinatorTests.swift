import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ChatSendCoordinatorTests {
  private let currentUserID = chatTestUUID(1)
  private let conversationID = chatTestUUID(10)

  @Test func pollFirstReconcilesAndLatePostCannotReviveBubble() async {
    let repository = TestChatRepository()
    await repository.suspendTextSends()
    let confirmed = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: currentUserID,
      clientID: "same-client"
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [confirmed], otherLastRead: nil, hasMore: false)
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
      text: "消息",
      clientID: "same-client"
    )
    let sendStarted = await chatEventually {
      await repository.pendingTextClientIDs().contains("same-client")
    }
    #expect(sendStarted)

    await viewModel.pollOnce()
    #expect(viewModel.messages.map(\.id) == [confirmed.id])
    #expect(coordinator.outbox(in: conversationID).isEmpty)

    await repository.resolveText(clientID: "same-client", with: .success(confirmed))
    let stayedSettled = await chatEventually {
      await MainActor.run { coordinator.outbox(in: self.conversationID).isEmpty }
    }
    #expect(stayedSettled)
  }

  @Test func postFirstIsConfirmedUntilViewModelAcknowledgesIt() async {
    let repository = TestChatRepository()
    let confirmed = chatTestMessage(
      conversationID: conversationID,
      seq: 2,
      senderID: currentUserID,
      clientID: "post-first"
    )
    await repository.enqueueTextSend(.message(confirmed))
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )

    coordinator.sendText(
      in: conversationID,
      text: "消息",
      clientID: "post-first"
    )
    let didConfirm = await chatEventually {
      await MainActor.run {
        guard let item = coordinator.outbox(in: self.conversationID).first else {
          return false
        }
        if case .confirmed = item.state {
          return true
        }
        return false
      }
    }
    #expect(didConfirm)

    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )

    #expect(viewModel.messages.map(\.id) == [confirmed.id])
    #expect(coordinator.outbox(in: conversationID).isEmpty)
  }

  @Test func concurrentSendsAreKeptAsIndependentOutboxItems() async {
    let repository = TestChatRepository()
    let first = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: currentUserID,
      clientID: "first"
    )
    let second = chatTestMessage(
      conversationID: conversationID,
      seq: 2,
      senderID: currentUserID,
      clientID: "second"
    )
    await repository.enqueueTextSend(.message(first))
    await repository.enqueueTextSend(.message(second))
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )

    coordinator.sendText(in: conversationID, text: "一", clientID: "first")
    coordinator.sendText(in: conversationID, text: "二", clientID: "second")
    let bothConfirmed = await chatEventually {
      await MainActor.run {
        coordinator.outbox(in: self.conversationID).count == 2
          && coordinator.outbox(in: self.conversationID).allSatisfy {
            if case .confirmed = $0.state { return true }
            return false
          }
      }
    }
    #expect(bothConfirmed)

    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )
    #expect(viewModel.messages.map(\.seq) == [1, 2])
    #expect(coordinator.outbox(in: conversationID).isEmpty)
  }

  @Test func failedSendSurvivesReentryAndRetryReusesClientID() async {
    let repository = TestChatRepository()
    let confirmed = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: currentUserID,
      clientID: "retry-client"
    )
    await repository.enqueueTextSend(.failure)
    await repository.enqueueTextSend(.message(confirmed))
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )

    coordinator.sendText(
      in: conversationID,
      text: "离页后失败",
      clientID: "retry-client"
    )
    let didFail = await chatEventually {
      await MainActor.run {
        guard let item = coordinator.outbox(in: self.conversationID).first else {
          return false
        }
        if case .failed = item.state { return true }
        return false
      }
    }
    #expect(didFail)

    let reenteredViewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )
    #expect(reenteredViewModel.pending.map(\.clientID) == ["retry-client"])

    reenteredViewModel.retry(clientID: "retry-client")
    let didRetry = await chatEventually {
      await MainActor.run { reenteredViewModel.messages.map(\.id) == [confirmed.id] }
    }
    #expect(didRetry)
    #expect(await repository.textClientIDs == ["retry-client", "retry-client"])
  }

  @Test func successfulSendWhilePoppedIsTransferredOnReentry() async {
    let repository = TestChatRepository()
    await repository.suspendTextSends()
    let confirmed = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: currentUserID,
      clientID: "popped-success"
    )
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    coordinator.sendText(
      in: conversationID,
      text: "离页后成功",
      clientID: "popped-success"
    )
    _ = await chatEventually {
      await repository.pendingTextClientIDs().contains("popped-success")
    }

    await repository.resolveText(clientID: "popped-success", with: .success(confirmed))
    let confirmedWithoutView = await chatEventually {
      await MainActor.run {
        guard let item = coordinator.outbox(in: self.conversationID).first else {
          return false
        }
        if case .confirmed = item.state { return true }
        return false
      }
    }
    #expect(confirmedWithoutView)

    let reenteredViewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )
    #expect(reenteredViewModel.messages.map(\.id) == [confirmed.id])
    #expect(coordinator.outbox(in: conversationID).isEmpty)
  }

}
