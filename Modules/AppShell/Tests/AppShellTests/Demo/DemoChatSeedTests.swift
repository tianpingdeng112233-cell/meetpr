import ChatUI
import StudentKit
import Testing

@testable import AppShell

@available(iOS 17.0, macOS 14.0, *)
@Test func studentDemoChatSeedKeepsCanonicalConversationSnapshot() throws {
  let user = DemoUserSeed.coachedStudent

  let seed = DemoChatSeed.make(for: user)

  let conversation = try #require(seed.conversations.first)
  #expect(seed.conversations.count == 1)
  #expect(conversation.id.uuidString == "00000000-0000-4000-8000-000000005841")
  #expect(conversation.otherPartyID == StudentDemoSeed.coachID)

  let messages = try #require(seed.messagesByConversationID[conversation.id])
  #expect(
    messages.map { $0.id.uuidString }
      == [
        "00000000-0000-4000-8000-000000005842",
        "00000000-0000-4000-8000-000000005843",
      ]
  )
  #expect(messages.map(\.seq) == [1, 2])
  #expect(messages.map(\.senderID) == [StudentDemoSeed.coachID, user.id])
  #expect(messages.map(\.text) == ["明天深蹲加到 140。", "收到。"])
}
