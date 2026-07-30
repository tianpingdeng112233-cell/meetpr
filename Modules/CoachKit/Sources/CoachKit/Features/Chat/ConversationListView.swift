import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

@MainActor
struct ConversationListView: View {
  let chat: CoachChatContext
  @State private var selectedConversation: ChatConversation?

  var body: some View {
    ScrollView {
      ConversationListSection(inbox: chat.inbox) { conversation in
        selectedConversation = conversation
      }
      .padding(MeetPRSpacing.pageHorizontal)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
    .navigationTitle(CoachStrings.messages)
    .modifier(CoachChatNavigationBarModifier())
    .navigationDestination(item: $selectedConversation) { conversation in
      CoachConversationDestination(
        conversationID: conversation.id,
        chat: chat,
        studentName: conversation.otherPartyName
      )
    }
  }
}

@MainActor
struct CoachConversationDestination: View {
  let conversationID: UUID
  let chat: CoachChatContext
  let studentName: String?
  let initialDraft: String
  let studentStatus: CoachStudentStatus?

  init(
    conversationID: UUID,
    chat: CoachChatContext,
    studentName: String? = nil,
    initialDraft: String = "",
    studentStatus: CoachStudentStatus? = nil
  ) {
    self.conversationID = conversationID
    self.chat = chat
    self.studentName = studentName
    self.initialDraft = initialDraft
    self.studentStatus = studentStatus
  }

  var body: some View {
    ConversationView(
      conversationID: conversationID,
      currentUserID: chat.currentUserID,
      repository: chat.repository,
      inbox: chat.inbox,
      sendCoordinator: chat.sendCoordinator,
      initialDraft: initialDraft,
      conversationTitle: resolvedStudentName,
      conversationSubtitle: statusPresentation.subtitle,
      conversationSubtitleColor: statusPresentation.color,
      outgoingBubbleColor: Color.MeetPR.textPrimary,
      incomingBubbleColor: Color.MeetPR.borderHairline,
      bubbleLayout: .directional,
      composerLayout: .compactPill
    )
    .modifier(CoachChatNavigationBarModifier())
    .coachFullScreenDestination()
  }

  private var resolvedStudentName: String {
    let preferredName = studentName?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let preferredName, !preferredName.isEmpty {
      return preferredName
    }
    let inboxName = chat.inbox.conversations.first {
      $0.id == conversationID
    }?.otherPartyName.trimmingCharacters(in: .whitespacesAndNewlines)
    if let inboxName, !inboxName.isEmpty {
      return inboxName
    }
    return CoachStrings.messages
  }

  private var statusPresentation: (subtitle: String?, color: Color) {
    CoachChatStatusSubtitle.presentation(for: studentStatus)
  }
}

private struct CoachChatNavigationBarModifier: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    #else
      content
    #endif
  }
}
