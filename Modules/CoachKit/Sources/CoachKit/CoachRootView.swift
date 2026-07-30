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
  private let privacyPolicyURL: URL?
  private let detailContext: CoachStudentDetailContext
  private let chat: CoachChatContext?
  private let draftStore: DraftStore
  @State private var rosterViewModel: StudentRosterViewModel
  @State private var queueViewModel: BindQueueViewModel
  @State private var videoQueueViewModel: CoachVideoQueueViewModel
  @State private var profileViewModel: CoachMyProfileViewModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var tabHostStore = CoachTabHostStore()
  @State private var selectedTab: CoachTab = .today
  @State private var acceptedStudentName: String?
  /// 教练端唯一时钟。日切 / 显著时间(时区)变化 / 回到前台时推进——
  /// 否则 app 停留过夜后,周概况仍停在昨天那一周(review-loop 2026-07-30)。
  @State private var now = Date()
  @State private var dashboardLoadTask: Task<Void, Never>?
  @State private var fullScreenDestinationIDs: Set<UUID> = []

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
    coachDisplayName: String? = nil,
    privacyPolicyURL: URL? = nil,
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
      initialValue: CoachMyProfileViewModel(
        displayName: coachDisplayName,
        logoutAction: onLogout
      )
    )
    self.privacyPolicyURL = privacyPolicyURL
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
    coachTabs
  }

  private var coachTabs: some View {
    let shell = CoachTabShellPresentation(selection: selectedTab)
    return ZStack {
      CoachDashboardView(
        context: detailContext,
        now: now,
        rows: rosterViewModel.rows,
        videos: videoQueueViewModel.items,
        applications: queueViewModel.items,
        conversations: chat?.inbox.conversations ?? [],
        acceptedStudentName: acceptedStudentName,
        onOpenMessages: { selectedTab = .messages },
        onOpenRoster: { selectedTab = .students },
        onEvaluationCompleted: { rosterViewModel.markStudentActive($0) },
        chat: chat
      )
      .coachTabLayer(shell.layer(for: .today), store: tabHostStore)

      CoachReceivingView(
        now: now,
        videoQueueViewModel: videoQueueViewModel,
        trainingLogs: studentLogs,
        studentStatuses: studentStatuses,
        chat: chat
      )
      .coachTabLayer(shell.layer(for: .messages), store: tabHostStore)

      StudentRosterView(
        viewModel: rosterViewModel,
        queueViewModel: queueViewModel,
        rows: rosterViewModel.filteredRows,
        now: now,
        context: detailContext,
        profiles: detailContext.profiles,
        onAccepted: { studentName in
          acceptedStudentName = studentName
          await rosterViewModel.refresh()
        },
        chat: chat,
        loadsOnAppear: false
      )
      .coachTabLayer(shell.layer(for: .students), store: tabHostStore)

      CoachMyProfileView(
        viewModel: profileViewModel,
        inviteCodes: inviteCodes,
        privacyPolicyURL: privacyPolicyURL
      )
      .coachTabLayer(shell.layer(for: .profile), store: tabHostStore)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .environment(\.coachNow, now)
    .environment(
      \.coachFullScreenDestinationRegistration,
      CoachFullScreenDestinationRegistration { destinationID, isActive in
        setFullScreenDestination(destinationID, isActive)
      }
    )
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if fullScreenDestinationIDs.isEmpty {
        MeetPRTabBar(
          selection: $selectedTab,
          items: [
            MeetPRTabBarItem(id: .today, title: CoachShellStrings.today, icon: .house),
            MeetPRTabBarItem(
              id: .messages,
              title: CoachStrings.messages,
              icon: .message,
              // Intentional prototype deviation: the badge uses unread message count,
              // not the number of conversations containing unread messages.
              badge: CoachMessageBadge.total(
                videos: videoQueueViewModel.pendingCount,
                chatUnread: chat?.inbox.totalUnread ?? 0
              )
            ),
            MeetPRTabBarItem(
              id: .students,
              title: CoachShellStrings.students,
              icon: .students,
              badge: queueViewModel.pendingCount
            ),
            MeetPRTabBarItem(id: .profile, title: CoachShellStrings.profile, icon: .profile),
          ],
          selectedColor: Color.MeetPR.gold500,
          unselectedColor: Color.MeetPR.textDisabled,
          badgeColor: Color.MeetPR.danger
        )
      }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      advanceClock()
    }
    #if os(iOS)
      .onReceive(
        NotificationCenter.default.publisher(
          for: UIApplication.significantTimeChangeNotification
        )
      ) { _ in
        advanceClock()
      }
    #endif
    .onReceive(
      NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)
    ) { _ in
      advanceClock()
    }
    .onAppear {
      guard dashboardLoadTask == nil else { return }
      dashboardLoadTask = Task {
        await loadDashboardData()
      }
    }
    .onDisappear {
      dashboardLoadTask?.cancel()
      dashboardLoadTask = nil
      chat?.inbox.stopPolling()
    }
    .onChange(of: selectedTab) { _, tab in
      switch tab {
      case .today: Analytics.shared.screen(.dashboard)
      case .students: Analytics.shared.screen(.coachRoster)
      case .messages: Analytics.shared.screen(.coachReceiving)
      case .profile: Analytics.shared.screen(.account)
      }
    }
  }

}

extension CoachRootView {
  fileprivate var studentStatuses: [UUID: CoachStudentStatus] {
    rosterViewModel.rows.reduce(into: [:]) { result, row in
      result[row.id] = row.student.status
    }
  }

  fileprivate func setFullScreenDestination(_ destinationID: UUID, _ isActive: Bool) {
    if isActive {
      fullScreenDestinationIDs.insert(destinationID)
    } else {
      fullScreenDestinationIDs.remove(destinationID)
    }
  }

  /// 推进统一时钟。跨过日界线时顺带重取一次 roster——本周的日志窗口已经换了一周,
  /// 光把 `now` 往前推只会让格子空着。
  fileprivate func advanceClock() {
    let updated = Date()
    let rolledOver = !CoachFeatureCalendar.isSameDay(updated, now)
    now = updated
    guard rolledOver else { return }
    Task { await rosterViewModel.refresh() }
  }

  fileprivate func loadDashboardData() async {
    Analytics.shared.screen(.dashboard)
    async let rosterRefresh: Void = rosterViewModel.loadIfNeeded()
    async let queueRefresh: Void = queueViewModel.loadIfNeeded()
    async let videoRefresh: Void = videoQueueViewModel.loadIfNeeded()
    _ = await (rosterRefresh, queueRefresh, videoRefresh)
    if let chat {
      await chat.inbox.refresh()
      chat.inbox.startPolling()
    }
  }
}

enum CoachMessageBadge {
  static func total(videos: Int, chatUnread: Int) -> Int {
    videos + chatUnread
  }
}
