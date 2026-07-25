import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct NotificationCenterSheet: View {
  let coordinator: StudentNotificationsCoordinator
  let onOpenPlan: () -> Void
  let onOpenFeedback: () -> Void
  let onOpenEvaluation: () -> Void
  let onOpenCoachMessages: @MainActor () async -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: MeetPRSpacing.space3) {
          if let planNotice = coordinator.planNotice {
            NotificationActionRow(
              systemImage: "calendar.badge.clock",
              title: "教练发布了新计划",
              subtitle: "第 \(planNotice.weekIndex) 周计划已可查看",
              action: close(after: onOpenPlan)
            )
          }
          if coordinator.feedbackUnreadCount > 0 {
            NotificationActionRow(
              systemImage: "bubble.left.and.text.bubble.right",
              title: "\(coordinator.feedbackUnreadCount) 条未读反馈",
              subtitle: "查看教练最近的训练反馈",
              action: close(after: onOpenFeedback)
            )
          }
          if coordinator.evaluationUnreadCount > 0 {
            NotificationActionRow(
              systemImage: "checkmark.seal",
              title: "评估已完成",
              subtitle: "打开完整评估总结",
              action: close(after: onOpenEvaluation)
            )
          }
          if let activeCoach = coordinator.activeCoach {
            NotificationActionRow(
              systemImage: "message",
              title: StudentStrings.coachMessages,
              subtitle: "\(activeCoach.coachDisplayName) · \(coordinator.coachMessagePreview)",
              unreadCount: coordinator.chatUnreadCount,
              action: close(afterAsync: onOpenCoachMessages)
            )
          }
          if isEmpty {
            ContentUnavailableView(
              "暂无新通知",
              systemImage: "bell",
              description: Text("新的反馈和计划会在这里出现")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
          }
        }
        .padding()
      }
      .background(Color.MeetPR.bgBase)
      .navigationTitle("通知")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("完成", action: { dismiss() })
        }
      }
    }
  }

  private var isEmpty: Bool {
    coordinator.planNotice == nil
      && coordinator.feedbackUnreadCount == 0
      && coordinator.evaluationUnreadCount == 0
      && !coordinator.hasActiveCoach
  }

  private func close(
    afterAsync action: @escaping @MainActor () async -> Void
  ) -> () -> Void {
    {
      dismiss()
      Task { @MainActor in
        await Task.yield()
        await action()
      }
    }
  }

  private func close(after action: @escaping () -> Void) -> () -> Void {
    {
      dismiss()
      Task { @MainActor in
        await Task.yield()
        action()
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NotificationActionRow: View {
  let systemImage: String
  let title: String
  let subtitle: String
  var unreadCount = 0
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.space3) {
        Image(systemName: systemImage)
          .font(.headline)
          .foregroundStyle(Color.MeetPR.gold500)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          Text(title)
            .font(.headline)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
        Spacer()
        if unreadCount > 0 {
          Text(unreadCount > 99 ? "99+" : unreadCount.formatted())
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, MeetPRSpacing.point5)
            .frame(minWidth: 18, minHeight: 18)
            .background(MeetPRSemanticTone.unread.color, in: .capsule)
        }
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .modifier(DashboardCard())
    }
    .buttonStyle(PressScaleButtonStyle())
  }
}
