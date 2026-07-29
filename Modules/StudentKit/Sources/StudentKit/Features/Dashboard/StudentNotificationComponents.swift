import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct StudentNotificationHostModifier: ViewModifier {
  let coordinator: StudentNotificationsCoordinator
  @Binding var showsNotifications: Bool
  @Binding var conversationID: UUID?
  let onOpenPlan: () -> Void
  @State private var isOpeningConversation = false

  func body(content: Content) -> some View {
    #if os(iOS)
      content
        .fullScreenCover(isPresented: conversationPresented) {
          conversationContent
        }
        .onChange(of: showsNotifications) { _, isPresented in
          guard isPresented else { return }
          showsNotifications = false
          openCoachConversation()
        }
    #else
      content
        .sheet(isPresented: conversationPresented) {
          conversationContent
        }
        .onChange(of: showsNotifications) { _, isPresented in
          guard isPresented else { return }
          showsNotifications = false
          openCoachConversation()
        }
    #endif
  }

  @ViewBuilder
  private var conversationContent: some View {
    if let conversationID, let chat = coordinator.chatContext {
      StudentBlackGoldChatView(
        conversationID: conversationID,
        coachName: coordinator.activeCoach?.coachDisplayName
          ?? coordinator.coachConversation?.otherPartyName
          ?? "",
        coordinator: coordinator,
        currentUserID: chat.currentUserID,
        repository: chat.repository,
        inbox: chat.inbox,
        sendCoordinator: chat.sendCoordinator,
        setRefSharing: chat.setRefSharing,
        onOpenTraining: onOpenPlan,
        dismiss: { self.conversationID = nil }
      )
    }
  }

  private var conversationPresented: Binding<Bool> {
    Binding(
      get: { conversationID != nil },
      set: { isPresented in
        if !isPresented {
          conversationID = nil
        }
      }
    )
  }

  private func openCoachConversation() {
    guard !isOpeningConversation else { return }
    isOpeningConversation = true
    Task { @MainActor in
      conversationID = await coordinator.openCoachConversation()
      isOpeningConversation = false
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct OptionalStudentNotificationHostModifier: ViewModifier {
  let coordinator: StudentNotificationsCoordinator?
  @Binding var showsNotifications: Bool
  @Binding var conversationID: UUID?
  let onOpenPlan: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if let coordinator {
      content.modifier(
        StudentNotificationHostModifier(
          coordinator: coordinator,
          showsNotifications: $showsNotifications,
          conversationID: $conversationID,
          onOpenPlan: onOpenPlan
        )
      )
    } else {
      content
    }
  }
}
