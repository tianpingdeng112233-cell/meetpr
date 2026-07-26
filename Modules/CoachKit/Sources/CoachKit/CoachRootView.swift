import Analytics
import ChatUI
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct CoachRootView: View {
  private let repository: any PlanRepository
  private let studentPlans: any StudentPlanRepository
  private let studentLogs: any StudentTrainingLogRepository
  private let feedback: any StudentFeedbackRepository
  private let inviteCodes: any InviteCodeRepository
  private let detailContext: CoachStudentDetailContext
  private let chat: CoachChatContext?
  private let draftStore: DraftStore
  @State private var rosterViewModel: StudentRosterViewModel
  @State private var queueViewModel: BindQueueViewModel
  @State private var videoQueueViewModel: CoachVideoQueueViewModel
  @State private var profileViewModel: CoachMyProfileViewModel
  @State private var selectedTab: CoachTab = .today

  @MainActor
  // swiftlint:disable:next function_body_length
  public init(
    repository: any PlanRepository = InMemoryPlanRepository.preview(),
    studentPlans: any StudentPlanRepository = EmptyStudentPlanRepository(),
    studentLogs: any StudentTrainingLogRepository = EmptyStudentTrainingLogRepository(),
    feedback: any StudentFeedbackRepository = EmptyStudentFeedbackRepository(),
    inviteCodes: (any InviteCodeRepository)? = nil,
    studentVideos: any CoachStudentVideoRepository = InMemoryCoachStudentVideoRepository(),
    readiness: any ReadinessRepository = EmptyReadinessRepository(),
    familyMapProvider: (any CoachPlanFamilyMapProviding)? = nil,
    bindQueue: (any CoachBindQueueRepository)? = nil,
    evaluations: (any EvaluationRepository)? = nil,
    evaluationSummaries: (any EvaluationSummaryRepository)? = nil,
    studentProfiles: (any OnboardingProfileReading)? = nil,
    videoQueue: (any CoachVideoQueueRepository)? = nil,
    chat: (any ChatRepository)? = nil,
    currentUserID: UUID? = nil,
    inbox: ChatInboxViewModel? = nil,
    sendCoordinator: ChatSendCoordinator? = nil,
    onLogout: @escaping @MainActor () async -> Void = {},
    draftStore: DraftStore = DraftStore.shared
  ) {
    self.repository = repository
    self.studentPlans = studentPlans
    self.studentLogs = studentLogs
    self.feedback = feedback
    self.inviteCodes = inviteCodes ?? InMemoryInviteCodeRepository()
    self.draftStore = draftStore
    let resolvedQueue =
      bindQueue ?? InMemoryCoachBindQueueRepository(coachId: UUID())
    let resolvedEvaluations = evaluations ?? InMemoryCoachEvaluationRepository()
    let resolvedSummaries =
      evaluationSummaries ?? InMemoryCoachEvaluationSummaryRepository(coachId: UUID())
    let resolvedProfiles = studentProfiles ?? InMemoryCoachStudentProfileReader()
    let resolvedChat = Self.chatContext(
      repository: chat,
      currentUserID: currentUserID,
      inbox: inbox,
      sendCoordinator: sendCoordinator
    )
    self.chat = resolvedChat
    detailContext = CoachStudentDetailContext(
      plans: studentPlans,
      trainingLogs: studentLogs,
      feedback: feedback,
      evaluations: resolvedEvaluations,
      summaries: resolvedSummaries,
      profiles: resolvedProfiles,
      videos: studentVideos,
      readiness: readiness,
      familyMapProvider: familyMapProvider,
      planning: repository,
      draftStore: draftStore,
      chat: resolvedChat
    )
    _rosterViewModel = State(
      initialValue: StudentRosterViewModel(
        students: repository,
        plans: studentPlans,
        trainingLogs: studentLogs,
        feedback: feedback
      )
    )
    _queueViewModel = State(
      initialValue: BindQueueViewModel(repository: resolvedQueue)
    )
    // Live default: aggregate the existing per-student video + feedback repos
    // (no new backend endpoint, spec 042). Demo injects an in-memory seed.
    let resolvedVideoQueue =
      videoQueue
      ?? AggregatingCoachVideoQueueRepository(
        roster: repository, videos: studentVideos, feedback: feedback, plans: studentPlans)
    _videoQueueViewModel = State(
      initialValue: CoachVideoQueueViewModel(repository: resolvedVideoQueue)
    )
    _profileViewModel = State(
      initialValue: CoachMyProfileViewModel(logoutAction: onLogout)
    )
  }

  private static func chatContext(
    repository: (any ChatRepository)?,
    currentUserID: UUID?,
    inbox: ChatInboxViewModel?,
    sendCoordinator: ChatSendCoordinator?
  ) -> CoachChatContext? {
    guard let repository, let currentUserID, let inbox, let sendCoordinator else {
      return nil
    }
    return CoachChatContext(
      repository: repository,
      currentUserID: currentUserID,
      inbox: inbox,
      sendCoordinator: sendCoordinator
    )
  }

  public var body: some View {
    ZStack {
      CoachDashboardView(
        attentionCount: rosterViewModel.pendingAttentionCount,
        pendingCount: queueViewModel.pendingCount,
        context: detailContext,
        rows: rosterViewModel.rows,
        onOpenReceiving: { selectedTab = .receiving },
        onOpenRoster: { selectedTab = .students },
        onEvaluationCompleted: { rosterViewModel.markStudentActive($0) },
        chat: chat
      )
      .modifier(CoachPageVisibility(tab: .today, selection: selectedTab))

      StudentRosterView(
        viewModel: rosterViewModel,
        context: detailContext,
        chat: chat
      )
      .modifier(CoachPageVisibility(tab: .students, selection: selectedTab))

      CoachPlanningHomeView(context: detailContext, chat: chat)
        .modifier(CoachPageVisibility(tab: .planning, selection: selectedTab))

      CoachReceivingView(
        pendingCount: queueViewModel.pendingCount,
        videoCount: videoQueueViewModel.pendingCount,
        queueViewModel: queueViewModel,
        videoQueueViewModel: videoQueueViewModel,
        profiles: detailContext.profiles,
        onAccepted: { await rosterViewModel.refresh() },
        chat: chat
      )
      .modifier(CoachPageVisibility(tab: .receiving, selection: selectedTab))

      CoachMyProfileView(
        viewModel: profileViewModel,
        inviteCodes: inviteCodes,
        chat: chat
      )
      .modifier(CoachPageVisibility(tab: .profile, selection: selectedTab))
    }
    .task {
      Analytics.shared.screen(.dashboard)
      await rosterViewModel.loadIfNeeded()
      await queueViewModel.loadIfNeeded()
      await videoQueueViewModel.loadIfNeeded()
      if let chat {
        await chat.inbox.refresh()
        chat.inbox.startPolling()
      }
    }
    .onDisappear {
      chat?.inbox.stopPolling()
    }
    .onChange(of: selectedTab) { _, tab in
      switch tab {
      case .today: Analytics.shared.screen(.dashboard)
      case .students: Analytics.shared.screen(.coachRoster)
      case .planning: Analytics.shared.screen(.coachPlanning)
      case .receiving: Analytics.shared.screen(.coachReceiving)
      case .profile: Analytics.shared.screen(.account)
      }
    }
    .meetPRCoachTabBar(
      selection: $selectedTab,
      studentsBadge: rosterViewModel.pendingAttentionCount,
      receivingBadge: CoachReceivingBadge.total(
        newStudents: queueViewModel.pendingCount,
        videos: videoQueueViewModel.pendingCount,
        chatUnread: chat?.inbox.totalUnread ?? 0
      )
    )
    .tint(Color.MeetPR.gold500)
  }
}

extension View {
  @ViewBuilder
  fileprivate func meetPRCoachTabBar(
    selection: Binding<CoachTab>,
    studentsBadge: Int,
    receivingBadge: Int
  ) -> some View {
    #if os(iOS)
      safeAreaInset(edge: .bottom, spacing: MeetPRSpacing.zero) {
        MeetPRTabBar(
          selection: selection,
          items: [
            MeetPRTabBarItem(id: .today, title: "今日", systemImage: "house"),
            MeetPRTabBarItem(
              id: .students,
              title: "学员",
              systemImage: "person.2",
              badge: studentsBadge
            ),
            MeetPRTabBarItem(
              id: .planning,
              title: "编排",
              systemImage: "calendar.badge.plus"
            ),
            MeetPRTabBarItem(
              id: .receiving,
              title: "接收",
              systemImage: "tray",
              badge: receivingBadge
            ),
            MeetPRTabBarItem(id: .profile, title: "我的", systemImage: "person"),
          ]
        )
      }
    #else
      self
    #endif
  }
}

enum CoachReceivingBadge {
  static func total(newStudents: Int, videos: Int, chatUnread: Int) -> Int {
    newStudents + videos + chatUnread
  }
}

private enum CoachTab: Hashable {
  case today
  case students
  case planning
  case receiving
  case profile
}

/// Keeps every coach page mounted while showing only the selected one —
/// same ZStack strategy as the student side (the system tab bar cannot be
/// hidden reliably on iOS 26, so no `TabView` is used at all).
@available(iOS 17.0, macOS 14.0, *)
private struct CoachPageVisibility: ViewModifier {
  let tab: CoachTab
  let selection: CoachTab

  func body(content: Content) -> some View {
    let isActive = tab == selection
    content
      .opacity(isActive ? 1 : 0)
      .allowsHitTesting(isActive)
      .accessibilityHidden(!isActive)
      .zIndex(isActive ? 1 : 0)
  }
}
