import Analytics
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Waiting-for-coach page (spec 031 §7). Refresh paths: pull-to-refresh,
/// onAppear, and scenePhase → .active (handled by BindGateView). APNs app
/// registration/routing is owned by spec 067; this state still uses refresh.
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
          Text(StudentStrings.localized(.pendingBindView001))
            .font(Font.MeetPR.title1)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(
            StudentStrings.replacing(
              .pendingBindView002,
              values: ["\(request.coachDisplayName ?? StudentStrings.localized(.bindGateView004))"]
            )
          )
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textSecondary)
        }

        waitingCard

        if let materialsSummary {
          materialsCard(materialsSummary)
        }

        Text(StudentStrings.localized(.pendingBindView003))
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.textTertiary)

        if let cancelError = viewModel.cancelError {
          Text(cancelError)
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.danger)
        }

        SecondaryButton(StudentStrings.localized(.pendingBindView004), isFullWidth: true) {
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
      StudentStrings.localized(.pendingBindView005),
      isPresented: $showsCancelConfirm,
      titleVisibility: .visible
    ) {
      Button(StudentStrings.localized(.pendingBindView004), role: .destructive) {
        Task { await performCancel() }
      }
      Button(StudentStrings.localized(.pendingBindView006), role: .cancel) {}
    } message: {
      Text(StudentStrings.localized(.pendingBindView007))
    }
  }

  private var waitingCard: some View {
    Card(accessibilityLabel: StudentStrings.localized(.pendingBindView008)) {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        let waited = PendingBindViewModel.waitingDescription(
          since: request.submittedAt, now: context.date)
        HStack(spacing: MeetPRSpacing.sm) {
          Image(systemName: "clock")
            .foregroundStyle(Color.MeetPR.textSecondary)
          Text(StudentStrings.replacing(.pendingBindView009, values: ["\(waited)"]))
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
    }
  }

  private func materialsCard(_ summary: PendingMaterialsSummary) -> some View {
    Card(accessibilityLabel: StudentStrings.localized(.pendingBindView010)) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow(StudentStrings.localized(.pendingBindView010))
        if summary.onboardingCompleted {
          Label(StudentStrings.localized(.pendingBindView011), systemImage: "checkmark.circle")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
        if summary.uploadCount > 0 {
          Label(
            StudentStrings.replacing(.pendingBindView012, values: ["\(summary.uploadCount)"]),
            systemImage: "doc.on.doc"
          )
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
