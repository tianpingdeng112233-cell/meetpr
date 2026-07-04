// swiftlint:disable type_body_length
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
  private let evaluationSummaryViewModel: StudentEvaluationSummaryViewModel?
  /// nil hides the row (demo/previews); live wiring passes Session.logout.
  private let onLogout: (@MainActor () async -> Void)?
  @State private var viewModel: MyProfileViewModel

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: any OnboardingRepository,
    evaluationSummaryViewModel: StudentEvaluationSummaryViewModel? = nil,
    onLogout: (@MainActor () async -> Void)? = nil
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.evaluationSummaryViewModel = evaluationSummaryViewModel
    self.onLogout = onLogout
    self._viewModel = State(
      initialValue: MyProfileViewModel(studentId: studentID, repo: onboarding))
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack {
          Text("我的资料")
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            content
          }
          .padding(16)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.reload() }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .hideNavigationBar()
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
    case .failed:
      Button {
        Task { await viewModel.reload() }
      } label: {
        Label("加载失败,点击重试", systemImage: "arrow.clockwise")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      .frame(maxWidth: .infinity, minHeight: 200)
    }
  }

  // MARK: - Sections

  @ViewBuilder
  private func sections(_ profile: OnboardingProfile) -> some View {
    sectionLabel("训练基线 · 教练管理")
    oneRMCard(profile).padding(.top, 8)
    // 基线是入门锚点,不是第三个「我的实力」(spec 050 §4)——实测走势
    // 归成长曲线,两个数字各安其位。
    Text("入门基线 · 实测走势见「成长」")
      .font(.caption)
      .foregroundStyle(Color.MeetPR.fgTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)

    sectionLabel("恢复与伤病 · 改动通知教练").padding(.top, 18)
    card {
      profileRow(
        "恢复评估", OnboardingSummaryFormatter.recovery(profile),
        push: true, kind: .recovery, profile: profile)
      divider
      profileRow(
        "伤病记录", OnboardingSummaryFormatter.injuries(profile),
        push: true, kind: .injuries, profile: profile)
    }
    .padding(.top, 8)

    sectionLabel("偏好与基础信息").padding(.top, 18)
    card {
      profileRow(
        "想增强肌群", OnboardingSummaryFormatter.muscleGroups(profile),
        push: false, kind: .materials, profile: profile)
      divider
      profileRow(
        "比赛日期", OnboardingSummaryFormatter.competition(profile),
        push: false, kind: .competition, profile: profile)
      divider
      profileRow(
        "身高 / 体重", heightWeightText(profile),
        push: false, kind: .basics, profile: profile)
    }
    .padding(.top, 8)

    sectionLabel("训练背景 · 环境").padding(.top, 18)
    card {
      profileRow(
        "训练背景", OnboardingSummaryFormatter.background(profile),
        push: false, kind: .background, profile: profile)
      divider
      profileRow(
        "训练环境", OnboardingSummaryFormatter.environment(profile),
        push: false, kind: .environment, profile: profile)
    }
    .padding(.top, 8)

    sectionLabel("更多").padding(.top, 18)
    moreCard.padding(.top, 8)
  }

  // MARK: - 1RM baseline card (locked)

  private func oneRMCard(_ profile: OnboardingProfile) -> some View {
    card(padding: 18) {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Text("当前 1RM")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
          Spacer()
          Image(systemName: "lock").font(.system(size: 14)).foregroundStyle(Color.MeetPR.fgTertiary)
        }
        HStack(spacing: 12) {
          oneRMValue("深蹲", profile.squat1RMKg)
          oneRMValue("卧推", profile.bench1RMKg)
          oneRMValue("硬拉", profile.deadlift1RMKg)
        }
        .padding(.top, 12)
        HStack(spacing: 6) {
          Image(systemName: "lock").font(.system(size: 12)).foregroundStyle(Color.MeetPR.fgTertiary)
          Text("训练周期中无法修改 · 联系教练")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
        .padding(.top, 14)
      }
    }
  }

  private func oneRMValue(_ label: String, _ value: Decimal?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).font(.system(size: 12)).foregroundStyle(Color.MeetPR.fgTertiary)
      HStack(alignment: .lastTextBaseline, spacing: 3) {
        Text(value.map { UnitDisplay.plainString($0) } ?? "—")
          .font(.system(size: 30, weight: .heavy).monospacedDigit())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("kg").font(.system(size: 12, design: .monospaced)).foregroundStyle(
          Color.MeetPR.fgTertiary)
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
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(label).font(.system(size: 14)).foregroundStyle(Color.MeetPR.fgTertiary)
            if push { notifyBadge }
          }
          Text(value)
            .font(.system(size: 17))
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Image(systemName: "chevron.right").font(.system(size: 15)).foregroundStyle(
          Color.MeetPR.fgTertiary)
      }
      .padding(16)
      .frame(minHeight: 64)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var notifyBadge: some View {
    Text("通知教练")
      .font(.system(size: 10, design: .monospaced))
      .tracking(0.5)
      .foregroundStyle(Color.MeetPR.brandRed)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .overlay {
        RoundedRectangle(cornerRadius: 3).stroke(Color.MeetPR.brandRed.opacity(0.3), lineWidth: 1)
      }
  }

  // MARK: - 更多 (kept features)

  private var moreCard: some View {
    card {
      NavigationLink {
        GrowthCurveView(studentID: studentID, plans: plans, e1rm: e1rm)
      } label: {
        moreRow(icon: "chart.xyaxis.line", title: "成长曲线")
      }
      .buttonStyle(.plain)

      if let evaluationSummaryViewModel, let summary = evaluationSummaryViewModel.summary {
        divider
        NavigationLink {
          EvaluationSummaryView(summary: summary) { evaluationSummaryViewModel.markRead() }
        } label: {
          moreRow(icon: "doc.text", title: "评估总结", showsDot: evaluationSummaryViewModel.isUnread)
        }
        .buttonStyle(.plain)
      }

      if let onLogout {
        divider
        LogoutRow(onLogout: onLogout)
      }
    }
  }

  private func moreRow(icon: String, title: String, showsDot: Bool = false) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon).font(.system(size: 16)).frame(width: 24).foregroundStyle(
        Color.MeetPR.fgSecondary)
      Text(title).font(.system(size: 15)).foregroundStyle(Color.MeetPR.fgPrimary)
      if showsDot {
        Circle().fill(Color.MeetPR.brandRed).frame(width: 8, height: 8)
      }
      Spacer()
      Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(
        Color.MeetPR.fgTertiary)
    }
    .padding(16)
    .contentShape(Rectangle())
  }

  // MARK: - Building blocks

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.fgSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func card<Content: View>(
    padding: CGFloat = 0, @ViewBuilder _ content: () -> Content
  ) -> some View {
    VStack(spacing: 0) { content() }
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  private var divider: some View {
    Rectangle().fill(Color.MeetPR.border).frame(height: 1)
  }

  private func stateMessage(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.fgTertiary)
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
      HStack(spacing: 12) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .font(.system(size: 16)).frame(width: 24)
        Text(isLoggingOut ? "退出中" : "退出登录").font(.system(size: 15, weight: .semibold))
        Spacer()
      }
      .foregroundStyle(Color.MeetPR.brandRed)
      .padding(16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isLoggingOut)
  }
}
// swiftlint:enable type_body_length
