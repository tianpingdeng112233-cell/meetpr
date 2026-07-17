import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct NotificationCenterSheet: View {
  let planNotice: DashboardPlanNotice?
  let feedbackUnreadCount: Int
  let onOpenPlan: () -> Void
  let onOpenFeedback: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 12) {
        if let planNotice {
          NotificationActionRow(
            systemImage: "calendar.badge.clock",
            title: "教练发布了新计划",
            subtitle: "第 \(planNotice.weekIndex) 周计划已可查看",
            action: close(after: onOpenPlan)
          )
        }
        if feedbackUnreadCount > 0 {
          NotificationActionRow(
            systemImage: "bubble.left.and.text.bubble.right",
            title: "\(feedbackUnreadCount) 条未读反馈",
            subtitle: "查看教练最近的训练反馈",
            action: close(after: onOpenFeedback)
          )
        }
        if isEmpty {
          ContentUnavailableView(
            "暂无新通知",
            systemImage: "bell",
            description: Text("新的反馈和计划会在这里出现")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        Spacer(minLength: 0)
      }
      .padding()
      .background(Color.MeetPR.bg)
      .navigationTitle("通知")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("完成", action: { dismiss() })
        }
      }
    }
  }

  private var isEmpty: Bool {
    planNotice == nil && feedbackUnreadCount == 0
  }

  private func close(after action: @escaping () -> Void) -> () -> Void {
    {
      action()
      dismiss()
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NotificationActionRow: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.headline)
          .foregroundStyle(Color.MeetPR.brandRed)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .modifier(DashboardCard())
    }
    .buttonStyle(.plain)
  }
}
