import Analytics
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Waiting-for-coach page (spec 031 §7). Refresh paths: pull-to-refresh,
/// onAppear, and scenePhase → .active (handled by BindGateView). No polling,
/// no push — V0.1b has no APNs (spec 031 D9) and the copy promises none.
@available(iOS 17.0, macOS 14.0, *)
struct PendingBindView: View {
  let request: BindRequest
  /// Submitted-materials summary; nil rows are hidden (027 not landed / N=0).
  let materialsSummary: PendingMaterialsSummary?
  let onCancelled: () -> Void
  let onStateMayHaveChanged: () async -> Void
  @State private var viewModel: PendingBindViewModel
  @State private var showsCancelConfirm = false

  init(
    request: BindRequest,
    materialsSummary: PendingMaterialsSummary?,
    bind: any RepositoryContracts.BindRepository,
    onCancelled: @escaping () -> Void,
    onStateMayHaveChanged: @escaping () async -> Void
  ) {
    self.request = request
    self.materialsSummary = materialsSummary
    self.onCancelled = onCancelled
    self.onStateMayHaveChanged = onStateMayHaveChanged
    self._viewModel = State(initialValue: PendingBindViewModel(bind: bind))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text("已发送绑定请求")
            .font(Font.MeetPR.title1)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("等待教练 \(request.coachDisplayName ?? "教练") 接收")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }

        waitingCard

        if let materialsSummary {
          materialsCard(materialsSummary)
        }

        Text("教练通常在 24-48 小时内响应;7 天未响应自动过期,可重新输码。")
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.textTertiary)

        if let cancelError = viewModel.cancelError {
          Text(cancelError)
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.gold500)
        }

        SecondaryButton("取消请求", isFullWidth: true) {
          showsCancelConfirm = true
        }
        .disabled(viewModel.isCancelling)
      }
      .padding(MeetPRSpacing.base)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bgBase)
    .onAppear { Analytics.shared.screen(.pendingBind) }
    .refreshable {
      await onStateMayHaveChanged()
    }
    .confirmationDialog(
      "取消绑定请求?",
      isPresented: $showsCancelConfirm,
      titleVisibility: .visible
    ) {
      Button("取消请求", role: .destructive) {
        Task { await performCancel() }
      }
      Button("继续等待", role: .cancel) {}
    } message: {
      Text("取消后可重新输入邀请码。")
    }
  }

  private var waitingCard: some View {
    Card(accessibilityLabel: "等待时长") {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        let waited = PendingBindViewModel.waitingDescription(
          since: request.submittedAt, now: context.date)
        HStack(spacing: MeetPRSpacing.sm) {
          Image(systemName: "clock")
            .foregroundStyle(Color.MeetPR.textSecondary)
          Text("已等待: \(waited)")
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
    }
  }

  private func materialsCard(_ summary: PendingMaterialsSummary) -> some View {
    Card(accessibilityLabel: "你已提交给教练的资料") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("你已提交给教练的资料")
        if summary.onboardingCompleted {
          Label("onboarding 完整资料", systemImage: "checkmark.circle")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
        if summary.uploadCount > 0 {
          Label("\(summary.uploadCount) 份上传资料", systemImage: "doc.on.doc")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
    }
  }

  private func performCancel() async {
    switch await viewModel.cancel(requestId: request.id) {
    case .cancelled:
      onCancelled()
    case .alreadyResponded:
      await onStateMayHaveChanged()
    case nil:
      break
    }
  }
}

/// Rows for the "submitted materials" card; built by the gate from the
/// optional onboarding profile (032 dependency — both rows hidden when the
/// profile is unavailable).
struct PendingMaterialsSummary: Equatable, Sendable {
  let onboardingCompleted: Bool
  let uploadCount: Int

  /// nil when there is nothing to show (hides the whole card).
  static func from(profile: OnboardingProfile?) -> PendingMaterialsSummary? {
    guard let profile else { return nil }
    let summary = PendingMaterialsSummary(
      onboardingCompleted: profile.isCompleted,
      uploadCount: profile.uploadAttachmentIds.count
    )
    guard summary.onboardingCompleted || summary.uploadCount > 0 else { return nil }
    return summary
  }
}
