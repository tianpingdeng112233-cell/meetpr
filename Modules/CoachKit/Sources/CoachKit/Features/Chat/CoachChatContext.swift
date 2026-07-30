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
  private(set) var destinationStudentName: String?
  private(set) var isOpening = false
  private(set) var errorMessage: String?

  init(chat: CoachChatContext?) {
    self.chat = chat
  }

  func openConversation(
    _ conversation: ChatConversation,
    studentName: String? = nil
  ) {
    guard chat != nil else {
      return
    }
    destinationStudentName = resolvedStudentName(
      preferred: studentName,
      conversation: conversation
    )
    destination = conversation
    errorMessage = nil
  }

  func openConversation(
    withOtherParty otherPartyID: UUID,
    studentName: String? = nil
  ) async {
    guard let chat, !isOpening else {
      return
    }
    isOpening = true
    defer { isOpening = false }
    do {
      let conversation = try await chat.repository.openConversation(
        withOtherParty: otherPartyID
      )
      await chat.inbox.refresh()
      destinationStudentName = resolvedStudentName(
        preferred: studentName,
        conversation: conversation
      )
      destination = conversation
      errorMessage = nil
    } catch {
      errorMessage = CoachStrings.unableToOpenConversation
    }
  }

  func dismissDestination() {
    destination = nil
    destinationStudentName = nil
  }

  func dismissError() {
    errorMessage = nil
  }

  private func resolvedStudentName(
    preferred preferredStudentName: String?,
    conversation: ChatConversation
  ) -> String {
    let preferredName = preferredStudentName?.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let conversationName = conversation.otherPartyName.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let studentName =
      preferredName.flatMap { $0.isEmpty ? nil : $0 }
      ?? (conversationName.isEmpty ? CoachStrings.messages : conversationName)
    return studentName
  }
}
