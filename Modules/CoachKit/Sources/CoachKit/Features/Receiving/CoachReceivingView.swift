// swiftlint:disable file_length type_body_length
import Analytics
import ChatUI
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Coach 接收 tab — a three-segment container (新学员 · 训练视频 · 消息),
/// reskinned to `DKCoachReceiving`. The 新学员 segment renders the live receive
/// queue from `BindQueueViewModel`; the 消息 segment reads the shared session
/// inbox so its rows and unread counts stay aligned with every header entry.
///
/// Backward compatible: the original `pendingCount` / `videoCount` initializer
/// still compiles. When the live `queueViewModel` + `profiles` are supplied
/// (see `CoachRootView`), the 新学员 segment binds to real rows; `pendingCount`
/// is then derived from the queue, so the passed value is ignored.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachReceivingView: View {
  private let fallbackPendingCount: Int
  private let fallbackVideoCount: Int
  private let queueViewModel: BindQueueViewModel?
  private let videoQueueViewModel: CoachVideoQueueViewModel?
  private let profiles: any OnboardingProfileReading
  private let chat: CoachChatContext?
  /// Called after a request is accepted so the caller can refresh the roster —
  /// `BindQueueViewModel` does not own the roster (spec 033 D1).
  private let onAccepted: () async -> Void

  @State private var segment: Segment = .students
  @State private var acceptTarget: CoachBindRequestItem?
  @State private var rejectTarget: CoachBindRequestItem?
  @State private var profileTarget: CoachBindRequestItem?
  @State private var videoStudentTarget: PendingVideoStudentGroup?
  @State private var selectedConversation: ChatConversation?
  @State private var isConversationListPresented = false

  enum Segment: Hashable { case students, videos, messages }

  /// `queueViewModel` / `videoQueueViewModel` default to nil so existing
  /// callers/tests that pass only counts keep compiling; supply them (and
  /// `profiles`) to bind live rows.
  init(
    pendingCount: Int,
    videoCount: Int,
    queueViewModel: BindQueueViewModel? = nil,
    videoQueueViewModel: CoachVideoQueueViewModel? = nil,
    profiles: any OnboardingProfileReading = InMemoryCoachStudentProfileReader(),
    onAccepted: @escaping () async -> Void = {},
    chat: CoachChatContext? = nil
  ) {
    self.fallbackPendingCount = pendingCount
    self.fallbackVideoCount = videoCount
    self.queueViewModel = queueViewModel
    self.videoQueueViewModel = videoQueueViewModel
    self.profiles = profiles
    self.onAccepted = onAccepted
    self.chat = chat
  }

  private var pendingCount: Int {
    queueViewModel?.pendingCount ?? fallbackPendingCount
  }

  private var videoCount: Int {
    videoQueueViewModel?.pendingCount ?? fallbackVideoCount
  }

  private var chatUnreadCount: Int {
    chat?.inbox.totalUnread ?? 0
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        header

        Group {
          switch segment {
          case .students:
            studentsSegment
          case .videos:
            videosSegment
          case .messages:
            messagesSegment
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .navigationDestination(item: $profileTarget) { item in
        StudentOnboardingProfileView(
          item: item,
          profiles: profiles,
          onAccept: { acceptTarget = item },
          onReject: { rejectTarget = item }
        )
      }
      .navigationDestination(item: $videoStudentTarget) { group in
        if let videoQueueViewModel {
          StudentPendingVideosView(
            studentID: group.studentID,
            studentName: group.studentName,
            viewModel: videoQueueViewModel
          )
        }
      }
      .navigationDestination(isPresented: $isConversationListPresented) {
        if let chat {
          ConversationListView(chat: chat)
        }
      }
      .navigationDestination(item: $selectedConversation) { conversation in
        if let chat {
          CoachConversationDestination(
            conversationID: conversation.id,
            chat: chat
          )
        }
      }
    }
    .sheet(item: $acceptTarget) { item in
      AcceptBindRequestSheet(studentName: item.displayName) { skipEvaluation, skipReason in
        guard let queueViewModel else { return false }
        let accepted = await queueViewModel.accept(
          item, skipEvaluation: skipEvaluation, skipReason: skipReason)
        if accepted {
          profileTarget = nil
          await onAccepted()
        }
        return accepted
      }
    }
    .confirmationDialog(
      "拒绝后学员会看到中性提示(不会显示拒绝原因),确定拒绝?",
      isPresented: rejectDialogBinding,
      titleVisibility: .visible
    ) {
      Button("拒绝", role: .destructive) {
        if let item = rejectTarget {
          Task {
            if await queueViewModel?.reject(item) == true {
              profileTarget = nil
            }
          }
        }
      }
      Button("取消", role: .cancel) {}
    }
    .task {
      await queueViewModel?.loadIfNeeded()
      await videoQueueViewModel?.loadIfNeeded()
    }
  }

  // MARK: - Header (reproduces DKCoachReceiving.header)

  private var header: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      HStack(alignment: .top, spacing: MeetPRSpacing.md) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Eyebrow("收件箱")
          Text("接收")
            .font(.MeetPR.display(size: 34, weight: .extraBold))
            .tracking(-0.7)
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
        Spacer(minLength: MeetPRSpacing.sm)
        CoachChatHeaderButton(chat: chat) {
          isConversationListPresented = true
        }
      }
      segmentedControl
        .padding(.top, MeetPRSpacing.md)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.xs)
    .padding(.bottom, MeetPRSpacing.md)
    .meetPRRiseIn(index: 0)
  }

  private var segmentedControl: some View {
    HStack(spacing: MeetPRSpacing.point3) {
      segButton(.students, label: "新学员", count: pendingCount)
      segButton(.videos, label: "训练视频", count: videoCount)
      if chat != nil {
        segButton(.messages, label: CoachStrings.messages, count: chatUnreadCount)
      }
    }
    .padding(MeetPRSpacing.point3)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md).stroke(
        Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }

  private func segButton(_ value: Segment, label: String, count: Int) -> some View {
    let active = segment == value
    return Button {
      segment = value
    } label: {
      HStack(spacing: MeetPRSpacing.point6) {
        Text(label).font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .semibold))
        Text("\(count)")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size10, design: .monospaced))
          .foregroundStyle(active ? Color.MeetPR.gold500 : Color.MeetPR.textTertiary)
          .padding(.horizontal, MeetPRSpacing.point6).padding(.vertical, MeetPRSpacing.point1)
          .background(active ? Color.MeetPR.goldSoft : .clear)
          .clipShape(.capsule)
      }
      .foregroundStyle(active ? Color.MeetPR.textPrimary : Color.MeetPR.textTertiary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.point9)
      .background(active ? Color.MeetPR.surfaceKey : .clear)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  @ViewBuilder
  private var messagesSegment: some View {
    if let chat {
      ScrollView {
        ConversationListSection(inbox: chat.inbox) { conversation in
          selectedConversation = conversation
        }
        .padding(MeetPRSpacing.base)
      }
      .scrollIndicators(.hidden)
    }
  }

  // MARK: - 新学员 segment (reproduces DKCoachReceiving request cards)

  @ViewBuilder
  private var studentsSegment: some View {
    if let queueViewModel {
      liveQueue(queueViewModel)
    } else {
      // No live VM injected (legacy count-only caller) — keep the original
      // scaffold empty-state so the screen never shows fabricated rows.
      emptyState(
        icon: "person.crop.circle.badge.plus",
        title: "新学员请求会出现在这里",
        subtitle: "学员扫码 / 输码并完成资料后,在这里接收或拒绝。")
    }
  }

  @ViewBuilder
  private func liveQueue(_ viewModel: BindQueueViewModel) -> some View {
    if viewModel.items.isEmpty {
      emptyState(
        icon: "person.crop.circle.badge.plus",
        title: "新学员请求会出现在这里",
        subtitle: "学员扫码 / 输码并完成资料后,在这里接收或拒绝。")
    } else {
      ScrollView {
        VStack(spacing: MeetPRSpacing.base) {
          if let banner = viewModel.bannerMessage {
            statusBanner(
              banner, systemImage: "exclamationmark.triangle", color: Color.MeetPR.danger)
          }
          if let toast = viewModel.toastMessage {
            statusBanner(toast, systemImage: "checkmark.circle", color: Color.MeetPR.success)
          }
          ForEach(viewModel.items) { item in
            requestCard(item, now: viewModel.now())
          }
        }
        .padding(MeetPRSpacing.base)
      }
      .scrollContentBackground(.hidden)
      .refreshable { await viewModel.refresh() }
    }
  }

  private func statusBanner(_ text: String, systemImage: String, color: Color) -> some View {
    Label(text, systemImage: systemImage)
      .font(Font.MeetPR.footnote)
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// One queue row, laid out to match the mock's request card. Every line is
  /// backed by a real onboarding field; absent fields are dropped (the mock's
  /// fixed five-line body degrades to whatever the student actually supplied).
  private func requestCard(_ item: CoachBindRequestItem, now: Date) -> some View {
    let onboarding = item.onboarding
    let expiringSoon = CoachOnboardingDisplay.isExpiringSoon(expiredAt: item.expiredAt, now: now)
    return VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      HStack(alignment: .firstTextBaseline) {
        Text(item.displayName)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer(minLength: MeetPRSpacing.sm)
        if expiringSoon {
          StatusBadge(status: .overdue, title: "即将过期")
        } else {
          monoLabel(
            CoachOnboardingDisplay.waitingText(since: item.submittedAt, now: now), size: 10)
        }
      }

      if onboarding.completed {
        completedBody(onboarding)
      } else {
        Text("资料未填写完成")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .padding(.top, MeetPRSpacing.xs)
      }

      // Assets row (mock "3 视频 + 1 计划" → real upload count, no breakdown).
      HStack(spacing: MeetPRSpacing.point6) {
        Image(systemName: "doc")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textTertiary)
        monoLabel(
          onboarding.uploadCount > 0 ? "\(onboarding.uploadCount) 份资料" : "无上传资料",
          size: 11)
      }
      .padding(.top, MeetPRSpacing.md)

      actionRow(item)
        .padding(.top, MeetPRSpacing.point14)
    }
    .padding(MeetPRSpacing.base)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(
          expiringSoon ? Color.MeetPR.gold500.opacity(0.3) : Color.MeetPR.borderDefault,
          lineWidth: 1)
    }
    .onAppear {
      Analytics.shared.coachIntakeAction(.requestSeen, studentID: item.studentId)
    }
  }

  /// Inlined equivalent of the AppShell `DKMonoLabel` (CoachKit cannot import
  /// AppShell — the dependency runs AppShell → CoachKit, not the reverse).
  private func monoLabel(_ text: String, size: CGFloat) -> some View {
    Text(text)
      .font(.MeetPR.system(size: size, weight: .medium, design: .monospaced))
      .tracking(0.8)
      .foregroundStyle(Color.MeetPR.textTertiary)
  }

  @ViewBuilder
  private func completedBody(_ onboarding: CoachBindRequestOnboardingSummary) -> some View {
    // Meta line: 性别 · 年龄 · 体重 · 训练年限 (each part omitted when absent).
    if let meta = metaLine(onboarding) {
      Text(meta)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .padding(.top, MeetPRSpacing.xs)
    }

    // SBD 1RM line (mock "S 180 · B 120 · D 220").
    Text(
      CoachOnboardingDisplay.oneRMTrio(
        squat: onboarding.squat1RMKg,
        bench: onboarding.bench1RMKg,
        deadlift: onboarding.deadlift1RMKg)
    )
    .font(.MeetPR.system(size: MeetPRFontMetrics.size14, design: .monospaced))
    .foregroundStyle(Color.MeetPR.textPrimary)
    .padding(.top, MeetPRSpacing.md)

    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      if !onboarding.muscleGroupsToStrengthen.isEmpty {
        Text("想增强:" + CoachOnboardingDisplay.muscleGroupList(onboarding.muscleGroupsToStrengthen))
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      if let tier = onboarding.gymTier {
        Text("训练环境:" + CoachOnboardingDisplay.gymTierText(tier))
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      if onboarding.isCompeting == true, let competitionDate = onboarding.competitionDate {
        Text("备赛:\(competitionDate)")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      if let note = onboarding.noteToCoach {
        Text("“\(note)”")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(2)
      }
    }
    .padding(.top, MeetPRSpacing.md)
  }

  private func metaLine(_ onboarding: CoachBindRequestOnboardingSummary) -> String? {
    var parts: [String] = []
    if let gender = onboarding.gender {
      parts.append(CoachOnboardingDisplay.genderText(gender))
    }
    if let age = CoachOnboardingDisplay.age(birthDate: onboarding.birthDate, now: Date()) {
      parts.append("\(age) 岁")
    }
    if let weight = onboarding.weightKg {
      parts.append("\(CoachOnboardingDisplay.decimalText(weight)) kg")
    }
    if let years = onboarding.trainingYears {
      parts.append(CoachOnboardingDisplay.trainingYearsText(years))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private func actionRow(_ item: CoachBindRequestItem) -> some View {
    HStack(spacing: MeetPRSpacing.sm) {
      // "接收" — opens the two-choice evaluation sheet (the mock's "▾"
      // disclosure is decorative; the real accept always presents the sheet).
      pillButton("接收", filled: true) { acceptTarget = item }
      pillButton("查看资料", filled: false) { profileTarget = item }
      Button {
        rejectTarget = item
      } label: {
        Image(systemName: "xmark")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size15, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(width: 48, height: 40)
          .overlay {
            RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(
              Color.MeetPR.borderDefault, lineWidth: 1)
          }
      }
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityLabel("拒绝 \(item.displayName)")
    }
  }

  private func pillButton(
    _ title: String, filled: Bool, action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(filled ? Color.MeetPR.bgBase : Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(filled ? Color.MeetPR.textPrimary : Color.clear)
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
        .overlay {
          if !filled {
            RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(
              Color.MeetPR.borderDefault, lineWidth: 1)
          }
        }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  // MARK: - 训练视频 segment (cross-student pending-video queue, spec 042)

  @ViewBuilder
  private var videosSegment: some View {
    if let videoQueueViewModel {
      videoQueue(videoQueueViewModel)
    } else {
      videosEmptyState
    }
  }

  @ViewBuilder
  private func videoQueue(_ viewModel: CoachVideoQueueViewModel) -> some View {
    if viewModel.items.isEmpty {
      videosEmptyState
    } else {
      ScrollView {
        VStack(spacing: MeetPRSpacing.base) {
          if let toast = viewModel.toastMessage {
            statusBanner(toast, systemImage: "checkmark.circle", color: Color.MeetPR.success)
          }
          if let banner = viewModel.bannerMessage {
            statusBanner(
              banner, systemImage: "exclamationmark.triangle", color: Color.MeetPR.danger)
          }
          ForEach(viewModel.studentGroups) { group in
            studentRow(group)
          }
        }
        .padding(MeetPRSpacing.base)
      }
      .scrollContentBackground(.hidden)
      .refreshable { await viewModel.refresh() }
    }
  }

  private var videosEmptyState: some View {
    emptyState(
      icon: "video",
      title: "学员训练视频会出现在这里",
      subtitle: "学员打卡上传的待反馈视频汇总在这里,逐条给文本反馈。")
  }

  /// One pending-video row, aggregated per student (spec 042 D1): name + 待反馈
  /// 段数 + 最近上传相对时间. Tapping opens that student's day-grouped videos.
  private func studentRow(_ group: PendingVideoStudentGroup) -> some View {
    Button {
      videoStudentTarget = group
    } label: {
      HStack(spacing: MeetPRSpacing.base) {
        ZStack {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .fill(Color.MeetPR.surfaceElevated)
            .frame(width: 56, height: 56)
          Image(systemName: "play.rectangle.fill")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size22))
            .foregroundStyle(Color.MeetPR.gold500)
        }
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          Text(group.studentName)
            .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          monoLabel(
            "\(group.count) 段待反馈 · \(CoachStudentFormatting.relativeText(group.latestUploadedAt))",
            size: 11)
        }
        Spacer(minLength: MeetPRSpacing.sm)
        Image(systemName: "chevron.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(
          Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel("\(group.studentName),\(group.count) 段待反馈,点按查看")
  }

  private func emptyState(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: MeetPRSpacing.md) {
      Image(systemName: icon).font(.MeetPR.system(size: MeetPRFontMetrics.size30)).foregroundStyle(
        Color.MeetPR.textTertiary)
      Text(title).font(Font.MeetPR.bodyEmphasis).foregroundStyle(Color.MeetPR.textPrimary)
      Text(subtitle)
        .font(Font.MeetPR.footnote).foregroundStyle(Color.MeetPR.textSecondary)
        .multilineTextAlignment(.center).frame(maxWidth: 260)
    }
    .padding(MeetPRSpacing.xl)
  }

  private var rejectDialogBinding: Binding<Bool> {
    Binding(
      get: { rejectTarget != nil },
      set: { isPresented in
        if !isPresented { rejectTarget = nil }
      }
    )
  }
}
// swiftlint:enable file_length type_body_length
