import ChatUI
import DesignSystem
import SwiftUI

/// Mounted for the lifetime of the student shell, including its conversation draft.
struct StudentCoachTab: View {
  let coordinator: StudentNotificationsCoordinator
  let isVisible: Bool
  let onOpenTraining: @MainActor () -> Void
  @State private var conversationID: UUID?
  @State private var failed = false

  var body: some View {
    NavigationStack {
      Group {
        if let conversationID, let chat = coordinator.chatContext {
          StudentBlackGoldChatView(
            conversationID: conversationID,
            coachName: coordinator.activeCoach?.coachDisplayName ?? "",
            coordinator: coordinator,
            currentUserID: chat.currentUserID,
            repository: chat.repository,
            inbox: chat.inbox,
            sendCoordinator: chat.sendCoordinator,
            setRefSharing: chat.setRefSharing,
            isVisible: isVisible,
            onOpenTraining: onOpenTraining,
            dismiss: {})
        } else if failed {
          ContentUnavailableView {
            Label(StudentConversationOpenFailure.network.title, systemImage: "wifi.exclamationmark")
          } description: {
            Text(StudentConversationOpenFailure.network.message)
          } actions: {
            Button(StudentStrings.localized(.studentBlackGoldChatView013)) {
              Task { await openConversation() }
            }
          }
        } else {
          ProgressView()
        }
      }
      .hideNavigationBar()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
    }
    .task(id: isVisible) {
      guard isVisible, conversationID == nil else { return }
      await openConversation()
    }
  }

  private func openConversation() async {
    failed = false
    switch await coordinator.openCoachConversation() {
    case .opened(let id): conversationID = id
    case .noActiveCoach, .bindRequired, .failed: failed = true
    }
  }
}
