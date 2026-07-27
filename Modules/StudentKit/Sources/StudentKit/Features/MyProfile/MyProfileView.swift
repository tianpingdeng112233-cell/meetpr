// swiftlint:disable file_length type_body_length function_body_length
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Black-gold v3 我的资料 tab. Existing onboarding, readiness, rest-timer,
/// account, export, and logout flows remain the only mutation paths.
@available(iOS 17.0, macOS 14.0, *)
public struct MyProfileView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let onboarding: any OnboardingRepository
  private let onLogout: (@MainActor () async -> Void)?
  private let account: (any AccountRepository)?
  private let logs: (any StudentTrainingLogRepository)?
  private let restTimerSettings: any StudentRestTimerSettingsStoring
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onOpenFeedbackNotification: () -> Void
  private let onOpenEvaluationNotification: () -> Void
  private let onOpenGrowth: (() -> Void)?

  @State private var viewModel: MyProfileViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var showsOneRMInfo = false
  @State private var showsReadiness = false
  @State private var showingNotifications = false
  @State private var conversationID: UUID?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: any OnboardingRepository,
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    evaluationSummaryViewModel _: StudentEvaluationSummaryViewModel? = nil,
    onLogout: (@MainActor () async -> Void)? = nil,
    account: (any AccountRepository)? = nil,
    logs: (any StudentTrainingLogRepository)? = nil,
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {},
    onOpenFeedbackNotification: @escaping () -> Void = {},
    onOpenEvaluationNotification: @escaping () -> Void = {},
    onOpenGrowth: (() -> Void)? = nil
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.onboarding = onboarding
    self.onLogout = onLogout
    self.account = account
    self.logs = logs
    self.restTimerSettings = restTimerSettings
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onOpenFeedbackNotification = onOpenFeedbackNotification
    self.onOpenEvaluationNotification = onOpenEvaluationNotification
    self.onOpenGrowth = onOpenGrowth
    self._viewModel = State(
      initialValue: MyProfileViewModel(studentId: studentID, repo: onboarding)
    )
    self._readinessViewModel = State(
      initialValue: ReadinessCheckinViewModel(repo: readiness)
    )
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          MyProfileHeader()
          content
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.point6)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollIndicators(.hidden)
      .scrollContentBackground(.hidden)
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
      .refreshable {
        await viewModel.reload()
        await readinessViewModel.load(studentId: studentID)
      }
    }
    .background(Color.MeetPR.bgBase)
    .task {
      await viewModel.loadIfNeeded()
      await readinessViewModel.load(studentId: studentID)
    }
    .sheet(isPresented: $showsReadiness) {
      ReadinessCheckinSheet(
        studentID: studentID,
        viewModel: readinessViewModel,
        prefill: currentReadiness,
        onClose: { showsReadiness = false }
      )
      .presentationDetents([.large])
    }
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      MyProfileSkeleton()
    case .loaded(let profile):
      loadedContent(profile)
    case .empty:
      MyProfileStateCard(text: "完成资料填写后解锁")
      fallbackRows
    case .failed:
      Button {
        Task { await viewModel.reload() }
      } label: {
        MyProfileStateCard(text: "加载失败 · 点击重试")
      }
      .buttonStyle(.plain)
      fallbackRows
    }
  }

  private func loadedContent(_ profile: OnboardingProfile) -> some View {
    let presentation = MyProfileV3Presentation.make(
      profile: profile,
      readiness: currentReadiness,
      restTimer: restTimerSettings.preference(for: studentID)
    )
    return VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      MyProfileOneRMCard(
        presentation: presentation,
        showsInfo: showsOneRMInfo,
        onToggleInfo: toggleOneRMInfo
      )

      MyProfileSectionLabel("恢复与伤病 · 改动通知教练")
        .padding(.top, MeetPRSpacing.point2)
      MyProfileRecoveryCard(
        title: "恢复评估",
        chips: presentation.recoveryChips,
        style: .recovery,
        action: { showsReadiness = true }
      )
      NavigationLink {
        ProfileCardEditView(kind: .injuries, profile: profile, viewModel: viewModel)
      } label: {
        MyProfileRecoveryCard(
          title: "伤病记录",
          chips: presentation.injuryChips,
          style: profile.injuryAreas.isEmpty ? .recovery : .injury,
          action: nil
        )
      }
      .buttonStyle(.plain)

      MyProfileSectionLabel("偏好与基础信息")
        .padding(.top, MeetPRSpacing.point2)
      MyProfileGroupCard {
        profileRow(
          "想增强肌群",
          presentation.muscleGroups,
          kind: .materials,
          profile: profile
        )
        MyProfileDivider()
        RestTimerPreferenceRow(studentID: studentID, settings: restTimerSettings)
        MyProfileDivider()
        profileRow(
          "比赛日期",
          presentation.competition,
          kind: .competition,
          profile: profile,
          highlightedValue: presentation.competitionDate
        )
        MyProfileDivider()
        profileRow(
          "身高 / 体重",
          presentation.heightAndWeight,
          kind: .basics,
          profile: profile
        )
      }

      MyProfileSectionLabel("训练背景 · 环境")
        .padding(.top, MeetPRSpacing.point2)
      MyProfileGroupCard {
        profileRow(
          "训练背景",
          presentation.trainingBackground,
          kind: .background,
          profile: profile
        )
        MyProfileDivider()
        profileRow(
          "训练环境",
          presentation.trainingEnvironment,
          kind: .environment,
          profile: profile
        )
      }

      MyProfileSectionLabel("更多")
        .padding(.top, MeetPRSpacing.point2)
      growthEntry

      accountSecuritySection

      if let onLogout {
        GoldCTA(
          "退出登录",
          sub: nil,
          variant: .danger,
          icon: .logout,
          action: {
            Task { await onLogout() }
          }
        )
        .padding(.top, MeetPRSpacing.space2)
      }
    }
  }

  private func profileRow(
    _ label: String,
    _ value: String,
    kind: ProfileCardKind,
    profile: OnboardingProfile,
    highlightedValue: String? = nil
  ) -> some View {
    NavigationLink {
      ProfileCardEditView(kind: kind, profile: profile, viewModel: viewModel)
    } label: {
      MyProfileValueRow(
        label: label,
        value: value,
        highlightedValue: highlightedValue
      )
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var growthEntry: some View {
    if let onOpenGrowth {
      Button(action: onOpenGrowth) {
        MyProfileIconRow(icon: "chart.xyaxis.line", title: "成长曲线")
      }
      .buttonStyle(.plain)
    } else {
      NavigationLink {
        GrowthCurveView(
          studentID: studentID,
          plans: plans,
          e1rm: e1rm,
          onboarding: onboarding
        )
      } label: {
        MyProfileIconRow(icon: "chart.xyaxis.line", title: "成长曲线")
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var accountSecuritySection: some View {
    if let account, let logs {
      MyProfileSectionLabel("账号与安全")
        .padding(.top, MeetPRSpacing.point2)
      AccountSecuritySection(
        studentID: studentID,
        account: account,
        logs: logs,
        plans: plans,
        onLogout: onLogout,
        showsDeleteAccount: false
      )
    }
  }

  @ViewBuilder
  private var fallbackRows: some View {
    MyProfileSectionLabel("偏好与基础信息")
    MyProfileGroupCard {
      RestTimerPreferenceRow(studentID: studentID, settings: restTimerSettings)
    }
    if let onLogout {
      GoldCTA(
        "退出登录",
        sub: nil,
        variant: .danger,
        icon: .logout,
        action: {
          Task { await onLogout() }
        }
      )
    }
  }

  private var currentReadiness: ReadinessCheckin? {
    guard case .done(let checkin) = readinessViewModel.gate else { return nil }
    return checkin
  }

  private func toggleOneRMInfo() {
    if reduceMotion {
      showsOneRMInfo.toggle()
    } else {
      withAnimation(MeetPRMotion.spring) {
        showsOneRMInfo.toggle()
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileHeader: View {
  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      MeetPRMark(size: 44)
        .frame(width: 92, height: MeetPRFontMetrics.size16, alignment: .leading)
        .clipped()
      Text("我的资料")
        .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("训练基线 · 教练管理")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .tracking(0.44)
        .foregroundStyle(Color.MeetPR.textFaint)
        .padding(.top, -MeetPRSpacing.space2)
    }
    .accessibilityElement(children: .combine)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileOneRMCard: View {
  let presentation: MyProfileV3Presentation
  let showsInfo: Bool
  let onToggleInfo: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        HStack(spacing: MeetPRSpacing.point6) {
          Text("当前 1RM")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textSecondary)
          Button(action: onToggleInfo) {
            Image(systemName: "info.circle")
              .font(.system(size: MeetPRFontMetrics.size14))
              .foregroundStyle(Color.MeetPR.textMuted)
              .frame(
                width: MeetPRSpacing.minimumHitTarget,
                height: MeetPRSpacing.minimumHitTarget
              )
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("说明当前 1RM")
        }
        Spacer()
        Image(systemName: "lock")
          .font(.system(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.textDim)
      }
      .frame(height: MeetPRSpacing.minimumHitTarget)
      .padding(.top, -MeetPRSpacing.point10)

      if showsInfo {
        Text("教练设定的训练基准 · 与「成长」按训练自动估算的 E1RM 不是同一个值")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
          .padding(.horizontal, MeetPRSpacing.point11)
          .padding(.vertical, MeetPRSpacing.point9)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.MeetPR.bgInset)
          .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
          .transition(.opacity.combined(with: .move(edge: .top)))
      }

      HStack(spacing: MeetPRSpacing.point10) {
        ForEach(presentation.oneRepMaxima, id: \.family) { item in
          VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
            Text(item.family.studentDisplayName)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
              .foregroundStyle(Color.MeetPR.textMuted)
            HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point2) {
              Text(item.kilograms.map(UnitDisplay.plainString) ?? "—")
                .font(.MeetPR.mono(size: MeetPRFontMetrics.size26, weight: .bold))
                .foregroundStyle(Color.MeetPR.textPrimary)
              Text("kg")
                .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
                .foregroundStyle(Color.MeetPR.textMuted)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.top, MeetPRSpacing.point14)

      HStack {
        Text("SBD 总和")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .tracking(0.36)
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer()
        HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point2) {
          Text(presentation.sbdTotalKg.map(UnitDisplay.plainString) ?? "—")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size24, weight: .bold))
          Text("kg")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
            .opacity(0.7)
        }
        .foregroundStyle(Color.MeetPR.goldText)
      }
      .padding(.top, MeetPRSpacing.point13)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(Color.MeetPR.surfaceRaised)
          .frame(height: 1)
      }
      .padding(.top, MeetPRSpacing.point14)

      Label("训练周期中无法修改 · 联系教练", systemImage: "lock")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textDim)
        .padding(.top, MeetPRSpacing.point11)
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

private enum MyProfileRecoveryStyle {
  case recovery
  case injury
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileRecoveryCard: View {
  let title: String
  let chips: [String]
  let style: MyProfileRecoveryStyle
  let action: (() -> Void)?

  var body: some View {
    Group {
      if let action {
        Button(action: action) { content }
          .buttonStyle(.plain)
      } else {
        content
      }
    }
  }

  private var content: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
        HStack(spacing: MeetPRSpacing.point7) {
          Text(title)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("通知教练")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size10, weight: .medium))
            .foregroundStyle(Color.MeetPR.goldText)
            .padding(.horizontal, MeetPRSpacing.point7)
            .padding(.vertical, MeetPRSpacing.point2)
            .background(Color.MeetPR.goldRGB.opacity(0.12))
            .clipShape(.rect(cornerRadius: MeetPRRadius.micro))
            .overlay {
              RoundedRectangle(cornerRadius: MeetPRRadius.micro)
                .stroke(Color.MeetPR.goldRGB.opacity(0.35), lineWidth: 1)
            }
        }
        HStack(spacing: MeetPRSpacing.space2) {
          ForEach(chips.indices.prefix(3), id: \.self) { index in
            if index > 0, style == .recovery {
              Rectangle()
                .fill(Color.MeetPR.borderStrong)
                .frame(width: 1, height: MeetPRSpacing.point11)
            }
            chipView(chips[index])
          }
        }
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.system(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDim)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .frame(minHeight: 76)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .contentShape(Rectangle())
  }

  private var chipForeground: Color {
    style == .injury ? Color.MeetPR.dangerMuted : Color.MeetPR.textSecondary
  }

  private var chipBackground: Color {
    style == .injury
      ? Color.MeetPR.dangerRGB.opacity(0.1)
      : Color.MeetPR.borderSubtle
  }

  private func chipView(_ chip: String) -> some View {
    HStack(spacing: MeetPRSpacing.point5) {
      if style == .injury {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: MeetPRFontMetrics.size12, weight: .semibold))
      }
      Text(chip)
    }
    .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
    .foregroundStyle(chipForeground)
    .padding(.horizontal, MeetPRSpacing.point9)
    .padding(.vertical, MeetPRSpacing.point3)
    .background(chipBackground)
    .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
    .overlay {
      if style == .injury {
        RoundedRectangle(cornerRadius: MeetPRRadius.inset)
          .stroke(Color.MeetPR.dangerRGB.opacity(0.4), lineWidth: 1)
      }
    }
    .lineLimit(1)
    .minimumScaleFactor(0.8)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct MyProfileValueRow: View {
  let label: String
  let value: String
  var highlightedValue: String?

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text(label)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
        valueText
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Image(systemName: "chevron.right")
        .font(.system(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDim)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .frame(minHeight: 68)
    .contentShape(Rectangle())
  }

  private var valueText: Text {
    guard let highlightedValue,
      let range = value.range(of: highlightedValue)
    else {
      return Text(value)
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
    return Text(String(value[..<range.lowerBound]))
      .foregroundStyle(Color.MeetPR.textPrimary)
      + Text(String(value[range]))
      .foregroundStyle(Color.MeetPR.goldText)
      + Text(String(value[range.upperBound...]))
      .foregroundStyle(Color.MeetPR.textPrimary)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileIconRow: View {
  let icon: String
  let title: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.point13) {
      Image(systemName: icon)
        .font(.system(size: MeetPRFontMetrics.size20))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(width: 20)
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Spacer()
      Image(systemName: "chevron.right")
        .font(.system(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDim)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point15)
    .frame(minHeight: 52)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .contentShape(Rectangle())
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct MyProfileGroupCard<Content: View>: View {
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(spacing: 0) {
      content
    }
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct MyProfileDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.MeetPR.borderSubtle)
      .frame(height: 1)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileSectionLabel: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
      .tracking(0.44)
      .foregroundStyle(Color.MeetPR.textFaint)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileSkeleton: View {
  var body: some View {
    VStack(spacing: MeetPRSpacing.point14) {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .fill(Color.MeetPR.textGhost.opacity(0.3))
        .frame(height: 190)
      ForEach(0..<4, id: \.self) { _ in
        RoundedRectangle(cornerRadius: MeetPRRadius.card)
          .fill(Color.MeetPR.textGhost.opacity(0.3))
          .frame(height: 76)
      }
    }
    .accessibilityLabel("正在加载我的资料")
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileStateCard: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
      .foregroundStyle(Color.MeetPR.textMuted)
      .frame(maxWidth: .infinity, minHeight: 120)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}
// swiftlint:enable file_length type_body_length function_body_length
