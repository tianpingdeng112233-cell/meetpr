import ChatUI
import CoreModels
import Foundation
import Observation
import RepositoryContracts

@MainActor
struct CoachChatContext {
  let repository: any ChatRepository
  let currentUserID: UUID
  let inbox: ChatInboxViewModel
  let sendCoordinator: ChatSendCoordinator
}

@Observable
@MainActor
final class CoachConversationOpener {
  private let chat: CoachChatContext?
  private(set) var destination: ChatConversation?
  private(set) var isOpening = false
  private(set) var errorMessage: String?

  init(chat: CoachChatContext?) {
    self.chat = chat
  }

  func openConversation(withOtherParty otherPartyID: UUID) async {
    guard let chat, !isOpening else {
      return
    }
    isOpening = true
    defer { isOpening = false }
    do {
      destination = try await chat.repository.openConversation(
        withOtherParty: otherPartyID
      )
      errorMessage = nil
      await chat.inbox.refresh()
    } catch {
      errorMessage = CoachStrings.unableToOpenConversation
    }
  }

  func dismissDestination() {
    destination = nil
  }

  func dismissError() {
    errorMessage = nil
  }
}
