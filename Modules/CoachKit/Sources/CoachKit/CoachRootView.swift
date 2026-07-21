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
    TabView(selection: $selectedTab) {
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
      .tag(CoachTab.today)
      .tabItem {
        Label("今日", systemImage: "house")
      }

      StudentRosterView(
        viewModel: rosterViewModel,
        context: detailContext,
        chat: chat
      )
      .tag(CoachTab.students)
      .tabItem {
        Label("学员", systemImage: "person.2")
      }
      // 待关注学员 (新学员 pending 计数已拆到「接收」tab, spec 033 D1).
      .badge(rosterViewModel.pendingAttentionCount)

      CoachPlanningHomeView(context: detailContext, chat: chat)
        .tag(CoachTab.planning)
        .tabItem {
          Label("编排", systemImage: "calendar.badge.plus")
        }

      CoachReceivingView(
        pendingCount: queueViewModel.pendingCount,
        videoCount: videoQueueViewModel.pendingCount,
        queueViewModel: queueViewModel,
        videoQueueViewModel: videoQueueViewModel,
        profiles: detailContext.profiles,
        onAccepted: { await rosterViewModel.refresh() },
        chat: chat
      )
      .tag(CoachTab.receiving)
      .tabItem {
        Label("接收", systemImage: "tray")
      }
      // 收件箱红点 = 新学员 + 待反馈视频 + 聊天未读(spec 058).
      .badge(
        CoachReceivingBadge.total(
          newStudents: queueViewModel.pendingCount,
          videos: videoQueueViewModel.pendingCount,
          chatUnread: chat?.inbox.totalUnread ?? 0
        )
      )

      CoachMyProfileView(
        viewModel: profileViewModel,
        inviteCodes: inviteCodes,
        chat: chat
      )
      .tag(CoachTab.profile)
      .tabItem {
        Label("我的", systemImage: "person")
      }
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
    .tint(Color.MeetPR.brandRed)
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
