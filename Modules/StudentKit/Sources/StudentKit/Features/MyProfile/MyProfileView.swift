// swiftlint:disable type_body_length file_length
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Tab "我的" (我的资料), reskinned to the design's three grouped sections:
/// the coach-managed training baseline (locked 1RMs), recovery/injury rows that
/// the coach can see, and preference/basic-info rows. Each editable row reuses
/// the existing `ProfileCardEditView` flow (same field sections as onboarding,
/// same save path — no behavior drift). 成长曲线 / 评估总结 / 退出登录 are kept
/// in a "更多" section beneath.
@available(iOS 17.0, macOS 14.0, *)
public struct MyProfileView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let onboarding: any OnboardingRepository
  private let evaluationSummaryViewModel: StudentEvaluationSummaryViewModel?
  /// nil hides the row (demo/previews); live wiring passes Session.logout.
  private let onLogout: (@MainActor () async -> Void)?
  private let account: (any AccountRepository)?
  private let logs: (any StudentTrainingLogRepository)?
  private let restTimerSettings: any StudentRestTimerSettingsStoring
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onOpenFeedbackNotification: () -> Void
  private let onOpenEvaluationNotification: () -> Void
  @State private var viewModel: MyProfileViewModel
  @State private var showingNotifications = false
  @State private var conversationID: UUID?

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: any OnboardingRepository,
    evaluationSummaryViewModel: StudentEvaluationSummaryViewModel? = nil,
    onLogout: (@MainActor () async -> Void)? = nil,
    account: (any AccountRepository)? = nil,
    logs: (any StudentTrainingLogRepository)? = nil,
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {},
    onOpenFeedbackNotification: @escaping () -> Void = {},
    onOpenEvaluationNotification: @escaping () -> Void = {}
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.onboarding = onboarding
    self.evaluationSummaryViewModel = evaluationSummaryViewModel
    self.onLogout = onLogout
    self.account = account
    self.logs = logs
    self.restTimerSettings = restTimerSettings
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onOpenFeedbackNotification = onOpenFeedbackNotification
    self.onOpenEvaluationNotification = onOpenEvaluationNotification
    self._viewModel = State(
      initialValue: MyProfileViewModel(studentId: studentID, repo: onboarding))
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        HStack {
          Text("我的资料")
            .font(.MeetPR.display(size: 34, weight: .extraBold))
            .tracking(-0.7)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
          if let notifications {
            StudentNotificationBell(coordinator: notifications) {
              showingNotifications = true
            }
          }
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.space2)
        .meetPRRiseIn(index: 0)

        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
            content
              .meetPRRiseIn(index: 1)
          }
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
          .padding(.vertical, MeetPRSpacing.point14)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.reload() }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .modifier(
        OptionalStudentNotificationHostModifier(
          coordinator: notifications,
          showsNotifications: $showingNotifications,
          conversationID: $conversationID,
          onOpenPlan: onOpenPlanNotification,
          onOpenFeedback: onOpenFeedbackNotification,
          onOpenEvaluation: onOpenEvaluationNotification
        )
      )
      .meetPRHideSystemTabBar()
    }
    .task { await viewModel.loadIfNeeded() }
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView().frame(maxWidth: .infinity, minHeight: 200)
    case .loaded(let profile):
      sections(profile)
    case .empty:
      stateMessage("完成资料填写后解锁")
      fallbackPreferencesSection
      fallbackLogoutSection
    case .failed:
      Button {
        Task { await viewModel.reload() }
      } label: {
        Label("加载失败,点击重试", systemImage: "arrow.clockwise")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      .frame(maxWidth: .infinity, minHeight: 200)
      fallbackPreferencesSection
      fallbackLogoutSection
    }
  }

  /// The rest-timer preference is device-local and independent of the
  /// onboarding profile, so it must stay reachable when the profile is empty
  /// or fails to load (spec 055 acceptance 2).
  @ViewBuilder
  private var fallbackPreferencesSection: some View {
    sectionLabel("偏好").padding(.top, MeetPRSpacing.point18)
    card { RestTimerPreferenceRow(studentID: studentID, settings: restTimerSettings) }
      .padding(.top, MeetPRSpacing.space2)
  }

  /// Escape hatch: 退出登录 must stay reachable even when the profile is empty
  /// or fails to load — an account without onboarding data would otherwise be
  /// trapped signed-in with the logout row hidden behind the profile gate
  /// (P0, found via staging debug account 2026-07-11).
  @ViewBuilder
  private var fallbackLogoutSection: some View {
    if let onLogout {
      sectionLabel("更多").padding(.top, MeetPRSpacing.point18)
      card { LogoutRow(onLogout: onLogout) }.padding(.top, MeetPRSpacing.space2)
    }
  }

  // MARK: - Sections

  @ViewBuilder
  // swiftlint:disable:next function_body_length
  private func sections(_ profile: OnboardingProfile) -> some View {
    if let notifications, notifications.hasActiveCoach {
      MyCoachCard(coordinator: notifications) {
        Task {
          conversationID = await notifications.openCoachConversation()
        }
      }
      .padding(.bottom, MeetPRSpacing.point18)
    }

    sectionLabel("训练基线 · 教练管理")
    oneRMCard(profile).padding(.top, MeetPRSpacing.space2)

    sectionLabel("恢复与伤病 · 改动通知教练").padding(.top, MeetPRSpacing.point18)
    card {
      profileRow(
        "恢复评估", OnboardingSummaryFormatter.recovery(profile),
        push: true, kind: .recovery, profile: profile)
      divider
      profileRow(
        "伤病记录", OnboardingSummaryFormatter.injuries(profile),
        push: true, kind: .injuries, profile: profile)
    }
    .padding(.top, MeetPRSpacing.space2)

    sectionLabel("偏好与基础信息").padding(.top, MeetPRSpacing.point18)
    card {
      profileRow(
        "想增强肌群", OnboardingSummaryFormatter.muscleGroups(profile),
        push: false, kind: .materials, profile: profile)
      divider
      RestTimerPreferenceRow(studentID: studentID, settings: restTimerSettings)
      divider
      AppearancePreferenceRow()
      divider
      profileRow(
        "比赛日期", OnboardingSummaryFormatter.competition(profile),
        push: false, kind: .competition, profile: profile)
      divider
      profileRow(
        "身高 / 体重", heightWeightText(profile),
        push: false, kind: .basics, profile: profile)
    }
    .padding(.top, MeetPRSpacing.space2)

    sectionLabel("训练背景 · 环境").padding(.top, MeetPRSpacing.point18)
    card {
      profileRow(
        "训练背景", OnboardingSummaryFormatter.background(profile),
        push: false, kind: .background, profile: profile)
      divider
      profileRow(
        "训练环境", OnboardingSummaryFormatter.environment(profile),
        push: false, kind: .environment, profile: profile)
    }
    .padding(.top, MeetPRSpacing.space2)

    sectionLabel("更多").padding(.top, MeetPRSpacing.point18)
    moreCard.padding(.top, MeetPRSpacing.space2)

    accountSecuritySection
  }

  @ViewBuilder
  private var accountSecuritySection: some View {
    if let account, let logs {
      sectionLabel("账号与安全").padding(.top, MeetPRSpacing.point18)
      AccountSecuritySection(
        studentID: studentID,
        account: account,
        logs: logs,
        plans: plans,
        onLogout: onLogout
      )
      .padding(.top, MeetPRSpacing.space2)
    }
  }

  // MARK: - 1RM baseline card (locked)

  private func oneRMCard(_ profile: OnboardingProfile) -> some View {
    card(padding: 18) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        HStack {
          Text("当前 1RM")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.gold500)
          Spacer()
          Image(systemName: "lock").font(.MeetPR.system(size: MeetPRFontMetrics.size14))
            .foregroundStyle(
              Color.MeetPR.textTertiary)
        }
        Text("教练设定的训练基准 · 与「成长」里按训练自动估算的 E1RM 不是同一个值")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.top, MeetPRSpacing.point6)
        HStack(spacing: MeetPRSpacing.space3) {
          oneRMValue("深蹲", profile.squat1RMKg)
          oneRMValue("卧推", profile.bench1RMKg)
          oneRMValue("硬拉", profile.deadlift1RMKg)
        }
        .padding(.top, MeetPRSpacing.space3)
        HStack(spacing: MeetPRSpacing.point6) {
          Image(systemName: "lock").font(.MeetPR.system(size: MeetPRFontMetrics.size12))
            .foregroundStyle(
              Color.MeetPR.textTertiary)
          Text("训练周期中无法修改 · 联系教练")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
        .padding(.top, MeetPRSpacing.point14)
      }
    }
  }

  private func oneRMValue(_ label: String, _ value: Decimal?) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
      Text(label).font(.MeetPR.system(size: MeetPRFontMetrics.size12)).foregroundStyle(
        Color.MeetPR.textTertiary)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point3) {
        Text(value.map { UnitDisplay.plainString($0) } ?? "—")
          .font(.MeetPR.display(size: 26, weight: .extraBold).monospacedDigit())
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text("kg").font(.MeetPR.system(size: MeetPRFontMetrics.size12, design: .monospaced))
          .foregroundStyle(
            Color.MeetPR.textTertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Rows

  private func profileRow(
    _ label: String, _ value: String, push: Bool, kind: ProfileCardKind,
    profile: OnboardingProfile
  ) -> some View {
    NavigationLink {
      ProfileCardEditView(kind: kind, profile: profile, viewModel: viewModel)
    } label: {
      HStack(spacing: MeetPRSpacing.space3) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          HStack(spacing: MeetPRSpacing.point6) {
            Text(label).font(.MeetPR.system(size: MeetPRFontMetrics.size14)).foregroundStyle(
              Color.MeetPR.textTertiary)
            if push { notifyBadge }
          }
          Text(value)
            .font(.MeetPR.system(size: MeetPRFontMetrics.size17))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Image(systemName: "chevron.right").font(.MeetPR.system(size: MeetPRFontMetrics.size15))
          .foregroundStyle(
            Color.MeetPR.textTertiary)
      }
      .padding(MeetPRSpacing.space4)
      .frame(minHeight: 64)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var notifyBadge: some View {
    Text("通知教练")
      .font(.MeetPR.system(size: MeetPRFontMetrics.size10, design: .monospaced))
      .tracking(0.5)
      .foregroundStyle(Color.MeetPR.gold500)
      .padding(.horizontal, MeetPRSpacing.point6)
      .padding(.vertical, MeetPRSpacing.point2)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.point3).stroke(
          Color.MeetPR.gold500.opacity(0.3), lineWidth: 1)
      }
  }

  // MARK: - 更多 (kept features)

  private var moreCard: some View {
    card {
      NavigationLink {
        GrowthCurveView(
          studentID: studentID,
          plans: plans,
          e1rm: e1rm,
          onboarding: onboarding
        )
      } label: {
        moreRow(icon: "chart.xyaxis.line", title: "成长曲线")
      }
      .buttonStyle(PressScaleButtonStyle())

      if let evaluationSummaryViewModel, let summary = evaluationSummaryViewModel.summary {
        divider
        NavigationLink {
          EvaluationSummaryView(summary: summary) { evaluationSummaryViewModel.markRead() }
        } label: {
          moreRow(icon: "doc.text", title: "评估总结", showsDot: evaluationSummaryViewModel.isUnread)
        }
        .buttonStyle(PressScaleButtonStyle())
      }

      if let onLogout {
        divider
        LogoutRow(onLogout: onLogout)
      }
    }
  }

  private func moreRow(icon: String, title: String, showsDot: Bool = false) -> some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Image(systemName: icon).font(.MeetPR.system(size: MeetPRFontMetrics.size16)).frame(width: 24)
        .foregroundStyle(
          Color.MeetPR.textSecondary)
      Text(title).font(.MeetPR.system(size: MeetPRFontMetrics.size15)).foregroundStyle(
        Color.MeetPR.textPrimary)
      if showsDot {
        Circle().fill(Color.MeetPR.gold500).frame(width: 8, height: 8)
      }
      Spacer()
      Image(systemName: "chevron.right").font(.MeetPR.system(size: MeetPRFontMetrics.size14))
        .foregroundStyle(
          Color.MeetPR.textTertiary)
    }
    .padding(MeetPRSpacing.space4)
    .contentShape(Rectangle())
  }

  // MARK: - Building blocks

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func card<Content: View>(
    padding: CGFloat = 0, @ViewBuilder _ content: () -> Content
  ) -> some View {
    VStack(spacing: MeetPRSpacing.zero) { content() }
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
          Color.MeetPR.borderDefault, lineWidth: 1)
      }
  }

  private var divider: some View {
    Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1)
  }

  private func stateMessage(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.textTertiary)
      .frame(maxWidth: .infinity, minHeight: 200)
  }

  private func heightWeightText(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if let height = profile.heightCm { parts.append("\(UnitDisplay.plainString(height)) cm") }
    if let weight = profile.weightKg { parts.append("\(UnitDisplay.plainString(weight)) kg") }
    return parts.isEmpty ? "未填写" : parts.joined(separator: " · ")
  }
}

/// "退出登录" — destructive logout row inside the 更多 card.
@available(iOS 17.0, macOS 14.0, *)
private struct LogoutRow: View {
  let onLogout: @MainActor () async -> Void
  @State private var isLoggingOut = false

  var body: some View {
    Button {
      isLoggingOut = true
      Task { await onLogout() }
    } label: {
      HStack(spacing: MeetPRSpacing.space3) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16)).frame(width: 24)
        Text(isLoggingOut ? "退出中" : "退出登录").font(
          .MeetPR.system(size: MeetPRFontMetrics.size15, weight: .semibold))
        Spacer()
      }
      .foregroundStyle(StudentVisualSemantics.destructiveAction.color)
      .padding(MeetPRSpacing.space4)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(isLoggingOut)
  }
}
// swiftlint:enable type_body_length
