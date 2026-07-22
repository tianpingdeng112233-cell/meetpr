import ChatUI
import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct StudentNotificationBell: View {
  let coordinator: StudentNotificationsCoordinator
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: coordinator.totalUnreadCount > 0 ? "bell.badge" : "bell")
        .font(.body.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(width: 44, height: 44)
        .overlay(alignment: .topTrailing) {
          if coordinator.totalUnreadCount > 0 {
            StudentUnreadBadge(count: coordinator.totalUnreadCount)
          }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(StudentStrings.notifications)
    .accessibilityValue(
      coordinator.totalUnreadCount > 0 ? StudentStrings.notificationsUnread : ""
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct StudentNotificationHostModifier: ViewModifier {
  let coordinator: StudentNotificationsCoordinator
  @Binding var showsNotifications: Bool
  @Binding var conversationID: UUID?
  let onOpenPlan: () -> Void
  let onOpenFeedback: () -> Void
  let onOpenEvaluation: () -> Void

  func body(content: Content) -> some View {
    content
      .navigationDestination(
        isPresented: Binding(
          get: { conversationID != nil },
          set: { isPresented in
            if !isPresented {
              conversationID = nil
            }
          }
        )
      ) {
        if let conversationID, let chat = coordinator.chatContext {
          ConversationView(
            conversationID: conversationID,
            currentUserID: chat.currentUserID,
            repository: chat.repository,
            inbox: chat.inbox,
            sendCoordinator: chat.sendCoordinator
          )
        }
      }
      .sheet(isPresented: $showsNotifications) {
        NotificationCenterSheet(
          coordinator: coordinator,
          onOpenPlan: {
            coordinator.markCurrentPlanSeen()
            onOpenPlan()
          },
          onOpenFeedback: onOpenFeedback,
          onOpenEvaluation: onOpenEvaluation,
          onOpenCoachMessages: openCoachConversation
        )
        .presentationDetents([.medium, .large])
      }
  }

  private func openCoachConversation() async {
    conversationID = await coordinator.openCoachConversation()
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct OptionalStudentNotificationHostModifier: ViewModifier {
  let coordinator: StudentNotificationsCoordinator?
  @Binding var showsNotifications: Bool
  @Binding var conversationID: UUID?
  let onOpenPlan: () -> Void
  let onOpenFeedback: () -> Void
  let onOpenEvaluation: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if let coordinator {
      content.modifier(
        StudentNotificationHostModifier(
          coordinator: coordinator,
          showsNotifications: $showsNotifications,
          conversationID: $conversationID,
          onOpenPlan: onOpenPlan,
          onOpenFeedback: onOpenFeedback,
          onOpenEvaluation: onOpenEvaluation
        )
      )
    } else {
      content
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct MyCoachCard: View {
  let coordinator: StudentNotificationsCoordinator
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.title2)
          .foregroundStyle(Color.MeetPR.brandRed)
          .frame(width: 36)
        VStack(alignment: .leading, spacing: 4) {
          Text(StudentStrings.myCoach)
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          Text(coordinator.activeCoach?.coachDisplayName ?? "")
            .font(.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(coordinator.coachMessagePreview)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        if coordinator.chatUnreadCount > 0 {
          StudentUnreadBadge(count: coordinator.chatUnreadCount)
        }
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .modifier(DashboardCard())
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct StudentUnreadBadge: View {
  let count: Int

  var body: some View {
    Text(count > 99 ? "99+" : count.formatted())
      .font(.caption2.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 5)
      .frame(minWidth: 18, minHeight: 18)
      .background(Color.MeetPR.brandRed, in: .capsule)
      .accessibilityLabel("\(count) \(StudentStrings.unreadSuffix)")
  }
}
