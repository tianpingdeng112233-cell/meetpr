import ChatUI
import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func studentChatTimelineMergesAllFourPresentationKindsByTimestamp() throws {
  let conversationID = UUID()
  let studentID = UUID()
  let coachID = UUID()
  let base = Date(timeIntervalSince1970: 1_800_000_000)
  let coachMessage = message(
    conversationID: conversationID,
    senderID: coachID,
    sequence: 1,
    text: "教练消息",
    at: base.addingTimeInterval(20)
  )
  let studentMessage = message(
    conversationID: conversationID,
    senderID: studentID,
    sequence: 2,
    text: "我的消息",
    at: base.addingTimeInterval(40)
  )
  let plan = DashboardPlanNotice(
    signature: DashboardPlanSignature(plan: StudentDemoSeed.makePlanView()),
    weekIndex: 1,
    occurredAt: base
  )
  let feedback = CoachFeedback(
    id: UUID(),
    coachID: coachID,
    studentID: studentID,
    text: "教练反馈",
    postedAt: base.addingTimeInterval(60)
  )

  let merged = StudentChatTimeline.merged(
    messages: [studentMessage, coachMessage],
    plan: plan,
    feedback: [feedback]
  )

  #expect(merged.count == 4)
  #expect(merged.map(\.occurredAt) == merged.map(\.occurredAt).sorted())
  #expect(itemKind(merged[0]) == .plan)
  #expect(itemKind(merged[1]) == .coachMessage)
  #expect(itemKind(merged[2]) == .studentMessage)
  #expect(itemKind(merged[3]) == .feedback)
}

private enum TimelineItemKind: Equatable {
  case plan
  case coachMessage
  case studentMessage
  case feedback
}

private func itemKind(_ item: StudentChatTimelineItem) -> TimelineItemKind {
  switch item {
  case .plan:
    .plan
  case .message(let message):
    message.text == "教练消息" ? .coachMessage : .studentMessage
  case .feedback:
    .feedback
  }
}

@Test func feedbackReadVisibilityMatchesMockupFiftyFivePercentBoundary() {
  let viewport = CGRect(x: 0, y: 0, width: 300, height: 200)
  let exactlyFiftyFivePercent = CGRect(x: 0, y: 145, width: 300, height: 100)
  let belowFiftyFivePercent = CGRect(x: 0, y: 146, width: 300, height: 100)

  #expect(
    StudentChatTimeline.visibleFraction(
      card: exactlyFiftyFivePercent,
      viewport: viewport
    ) == 0.55
  )
  #expect(
    StudentChatTimeline.visibleFraction(
      card: belowFiftyFivePercent,
      viewport: viewport
    ) == 0.54
  )
  #expect(
    StudentChatTimeline.visibleFraction(card: .zero, viewport: viewport) == 0
  )
}

@Test func chatVideoLabelUsesSameOneBasedSetNumberAsFeedbackArchive() {
  let video = CoachFeedbackVideo(
    id: UUID(),
    exerciseName: "暂停深蹲",
    setIndex: 0
  )

  #expect(FeedbackVideoPresentation.summary(video).contains("第1组"))
  #expect(StudentChatTimeline.videoLabel(for: video) == "我的暂停深蹲 · 第 1 组")
}

@MainActor
// swiftlint:disable:next function_body_length
@Test func studentChatHistoryPagingPrependsOlderMessagesAndReturnsStableAnchor() async {
  let conversationID = UUID()
  let studentID = UUID()
  let coachID = UUID()
  let base = Date(timeIntervalSince1970: 1_800_000_000)
  let messages = (1...3).map { sequence in
    message(
      conversationID: conversationID,
      senderID: studentID,
      sequence: sequence,
      text: "消息 \(sequence)",
      at: base.addingTimeInterval(Double(sequence))
    )
  }
  let repository = InMemoryChatRepository(
    currentUserID: studentID,
    seed: ChatDemoSeed(
      conversations: [
        ChatConversation(
          id: conversationID,
          otherPartyID: coachID,
          otherPartyName: "周教练",
          lastMessagePreview: "消息 3",
          lastMessageAt: messages.last?.createdAt,
          unreadCount: 0,
          myLastRead: nil,
          otherLastRead: nil
        )
      ],
      messagesByConversationID: [conversationID: messages],
      otherPartyNames: [coachID: "周教练"]
    )
  )
  let viewModel = ConversationViewModel(
    conversationID: conversationID,
    currentUserID: studentID,
    repository: repository,
    sendCoordinator: ChatSendCoordinator(
      repository: repository,
      currentUserID: studentID
    ),
    pageLimit: 2
  )

  await viewModel.load()
  #expect(viewModel.messages.map(\.seq) == [2, 3])
  #expect(viewModel.hasMoreHistory)

  let anchor = await StudentChatTimeline.loadOlderPreservingPosition(
    in: viewModel,
    plan: nil,
    feedback: []
  )

  #expect(viewModel.messages.map(\.seq) == [1, 2, 3])
  #expect(anchor == "message-\(messages[1].id.uuidString)")
  #expect(!viewModel.hasMoreHistory)
}

private func message(
  conversationID: UUID,
  senderID: UUID,
  sequence: Int,
  text: String,
  at date: Date
) -> ChatMessage {
  ChatMessage(
    id: UUID(),
    conversationID: conversationID,
    seq: sequence,
    senderID: senderID,
    kind: .text,
    text: text,
    attachmentID: nil,
    imageURL: nil,
    imageExpiresIn: nil,
    clientID: "message-\(sequence)",
    createdAt: date
  )
}
