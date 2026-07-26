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
  let onOpenPlan: () -> Void
  let onOpenFeedback: () -> Void
  let onOpenEvaluation: () -> Void

  func body(content: Content) -> some View {
    content
      // The design has no notification hub: the header bubble goes straight
      // into the coach conversation, where plan and feedback events live as
      // stream cards. The legacy sheet only remains for accounts without chat.
      .onChange(of: showsNotifications) { _, isPresented in
        guard isPresented, coordinator.chatContext != nil else { return }
        showsNotifications = false
        // Presentation lives on the shared coordinator (root full-screen
        // cover), which is single-flight across every mounted tab.
        coordinator.requestCoachConversation()
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

  private func openCoachConversation() async {
    coordinator.requestCoachConversation()
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct OptionalStudentNotificationHostModifier: ViewModifier {
  let coordinator: StudentNotificationsCoordinator?
  @Binding var showsNotifications: Bool
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

/// Presents the coach conversation as a root-level full-screen cover — the
/// mockup's chat overlay — fed by the shared coordinator so exactly one
/// conversation can ever be up regardless of which tab asked for it.
@available(iOS 17.0, macOS 14.0, *)
struct StudentRootConversationCover: ViewModifier {
  let coordinator: StudentNotificationsCoordinator?
  let onOpenPlan: () -> Void
  let onOpenFeedback: () -> Void
  let onOpenEvaluation: () -> Void

  func body(content: Content) -> some View {
    if let coordinator {
      content
        #if os(iOS)
          .fullScreenCover(
            isPresented: Binding(
              get: { coordinator.presentedConversationID != nil },
              set: { if !$0 { coordinator.dismissCoachConversation() } }
            )
          ) {
            coverContent(coordinator)
          }
        #else
          .sheet(
            isPresented: Binding(
              get: { coordinator.presentedConversationID != nil },
              set: { if !$0 { coordinator.dismissCoachConversation() } }
            )
          ) {
            coverContent(coordinator)
          }
        #endif
    } else {
      content
    }
  }

  @ViewBuilder
  private func coverContent(_ coordinator: StudentNotificationsCoordinator) -> some View {
    if let conversationID = coordinator.presentedConversationID,
      let chat = coordinator.chatContext
    {
      NavigationStack {
        ConversationView(
          conversationID: conversationID,
          currentUserID: chat.currentUserID,
          repository: chat.repository,
          inbox: chat.inbox,
          sendCoordinator: chat.sendCoordinator,
          events: events(coordinator)
        )
        .toolbar {
          Button("关闭") { coordinator.dismissCoachConversation() }
            .foregroundStyle(Color.MeetPR.gold500)
        }
      }
    }
  }

  /// Plan, feedback, and evaluation surfaced as in-stream cards.
  private func events(_ coordinator: StudentNotificationsCoordinator) -> [ConversationEventItem] {
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
          dismissThenRoute(coordinator, onOpenPlan)
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
          dismissThenRoute(coordinator, onOpenFeedback)
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
          dismissThenRoute(coordinator, onOpenEvaluation)
        }
      )
    }
    return items
  }

  private func dismissThenRoute(
    _ coordinator: StudentNotificationsCoordinator,
    _ route: @escaping () -> Void
  ) {
    coordinator.dismissCoachConversation()
    Task { @MainActor in
      await Task.yield()
      route()
    }
  }
}
