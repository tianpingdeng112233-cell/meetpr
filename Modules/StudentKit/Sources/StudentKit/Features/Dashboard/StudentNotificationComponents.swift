import ChatUI
import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct StudentNotificationBell: View {
  let coordinator: StudentNotificationsCoordinator
  let action: () -> Void

  var body: some View {
    HeaderChatButton(
      unreadCount: coordinator.totalUnreadCount,
      accessibilityLabel: StudentStrings.notifications
    ) {
      action()
    }
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
  @State private var isOpeningConversation = false
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
            sendCoordinator: chat.sendCoordinator,
            events: conversationEvents
          )
        }
      }
      // The design has no notification hub: the header bubble goes straight
      // into the coach conversation, where plan and feedback events live as
      // stream cards. The legacy sheet only remains for accounts without chat.
      .onChange(of: showsNotifications) { _, isPresented in
        guard isPresented, coordinator.chatContext != nil else { return }
        showsNotifications = false
        // Single-flight: taps during the open request (or while the
        // conversation is already up) must not stack another push.
        guard !isOpeningConversation, conversationID == nil else { return }
        isOpeningConversation = true
        Task {
          await openCoachConversation()
          isOpeningConversation = false
        }
      }
      .sheet(
        isPresented: Binding(
          get: { showsNotifications && coordinator.chatContext == nil },
          set: { if !$0 { showsNotifications = false } }
        )
      ) {
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

  /// Plan and feedback surfaced as in-stream cards, per the mockup.
  private var conversationEvents: [ConversationEventItem] {
    var items: [ConversationEventItem] = []
    if let notice = coordinator.planNotice {
      items.append(
        ConversationEventItem(
          id: "plan-w\(notice.weekIndex)",
          kind: .planPublished,
          title: "教练发布了新计划",
          subtitle: "第 \(notice.weekIndex) 周计划已可查看",
          isUnread: true
        ) {
          coordinator.markCurrentPlanSeen()
          closeConversationThenRoute(onOpenPlan)
        }
      )
    }
    let unreadFeedback = coordinator.feedbackUnreadCount
    if unreadFeedback > 0 {
      items.append(
        ConversationEventItem(
          id: "feedback-unread",
          kind: .feedback,
          title: "\(unreadFeedback) 条未读反馈",
          subtitle: "查看教练最近的训练反馈",
          isUnread: true
        ) {
          closeConversationThenRoute(onOpenFeedback)
        }
      )
    }
    if coordinator.evaluationUnreadCount > 0 {
      items.append(
        ConversationEventItem(
          id: "evaluation-unread",
          kind: .evaluation,
          title: "评估总结已发布",
          subtitle: "查看教练的评估结论",
          isUnread: true
        ) {
          closeConversationThenRoute(onOpenEvaluation)
        }
      )
    }
    return items
  }

  /// Pop the conversation first, yield so the dismissal lands its own
  /// transaction, then route — mirroring the legacy sheet's ordering.
  private func closeConversationThenRoute(_ route: @escaping () -> Void) {
    conversationID = nil
    Task { @MainActor in
      await Task.yield()
      route()
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
      HStack(spacing: MeetPRSpacing.space3) {
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.title2)
          .foregroundStyle(Color.MeetPR.gold500)
          .frame(width: 36)
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          Text(StudentStrings.myCoach)
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.textSecondary)
          Text(coordinator.activeCoach?.coachDisplayName ?? "")
            .font(.headline)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(coordinator.coachMessagePreview)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.textTertiary)
            .lineLimit(1)
        }
        Spacer(minLength: 8)
        if coordinator.chatUnreadCount > 0 {
          StudentUnreadBadge(count: coordinator.chatUnreadCount)
        }
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .modifier(DashboardCard())
      .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle())
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct StudentUnreadBadge: View {
  let count: Int

  var body: some View {
    Text(count > 99 ? "99+" : count.formatted())
      .font(.caption2.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, MeetPRSpacing.point5)
      .frame(minWidth: 18, minHeight: 18)
      .background(MeetPRSemanticTone.unread.color, in: .capsule)
      .accessibilityLabel("\(count) \(StudentStrings.unreadSuffix)")
  }
}
