import CoreModels
import Foundation
import Testing

@testable import ChatUI

@MainActor
@Test func confirmationPreservesPendingGroupAndPositionAcrossFiveMinuteBoundary() async throws {
  let base = Date(timeIntervalSince1970: 1_800_000_000)
  let conversationID = UUID()
  let userID = UUID()
  let repository = TestChatRepository()
  await repository.suspendTextSends()
  let coordinator = ChatSendCoordinator(
    repository: repository, currentUserID: userID, now: { base.addingTimeInterval(299) })
  let model = ConversationViewModel(
    conversationID: conversationID, currentUserID: userID,
    repository: repository, sendCoordinator: coordinator)
  let first = timelineMessage(conversationID: conversationID, senderID: UUID(), seq: 1, date: base)
  model.messages = [first]
  coordinator.sendText(in: conversationID, text: "local", clientID: "local")
  let before = model.timelineItems
  #expect(before.count == 2)
  #expect(ChatRelativeTime.separators(timestamps: before.map(\.groupingDate)).keys.sorted() == [0])
  let incoming = timelineMessage(
    conversationID: conversationID, senderID: UUID(), seq: 2, date: base.addingTimeInterval(300))
  model.messages.append(incoming)
  #expect(model.timelineItems.map(\.id) == [before[0].id, before[1].id, "message-\(incoming.id)"])
  let started = await chatEventually { await repository.pendingTextClientIDs().contains("local") }
  #expect(started)
  let confirmed = timelineMessage(
    conversationID: conversationID, senderID: userID, seq: 3,
    date: base.addingTimeInterval(301), clientID: "local")
  await repository.resolveText(clientID: "local", with: .success(confirmed))
  let settled = await chatEventually { await MainActor.run { model.pending.isEmpty } }
  #expect(settled)
  let after = model.timelineItems
  #expect(after.map(\.id) == [before[0].id, before[1].id, "message-\(incoming.id)"])
  #expect(after[1].timestamp == confirmed.createdAt)
  #expect(ChatRelativeTime.separators(timestamps: after.map(\.groupingDate)).keys.sorted() == [0])
  await coordinator.cancelAllAndWaitForCleanup()
}

private func timelineMessage(
  conversationID: UUID, senderID: UUID, seq: Int, date: Date, clientID: String = UUID().uuidString
) -> ChatMessage {
  ChatMessage(
    id: UUID(), conversationID: conversationID, seq: seq, senderID: senderID, kind: .text,
    text: "message", attachmentID: nil, imageURL: nil, imageExpiresIn: nil,
    clientID: clientID, createdAt: date)
}
