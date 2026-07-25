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
      .padding(MeetPRSpacing.base)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
    .navigationTitle(CoachStrings.messages)
    .modifier(CoachChatNavigationBarModifier())
    .navigationDestination(item: $selectedConversation) { conversation in
      CoachConversationDestination(
        conversationID: conversation.id,
        chat: chat
      )
    }
  }
}

@MainActor
struct CoachConversationDestination: View {
  let conversationID: UUID
  let chat: CoachChatContext

  var body: some View {
    ConversationView(
      conversationID: conversationID,
      currentUserID: chat.currentUserID,
      repository: chat.repository,
      inbox: chat.inbox,
      sendCoordinator: chat.sendCoordinator
    )
    .modifier(CoachChatNavigationBarModifier())
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
