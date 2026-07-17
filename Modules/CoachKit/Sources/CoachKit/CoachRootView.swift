import DesignSystem
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
  private let draftStore: DraftStore
  @State private var rosterViewModel: StudentRosterViewModel
  @State private var queueViewModel: BindQueueViewModel
  @State private var videoQueueViewModel: CoachVideoQueueViewModel
  @State private var profileViewModel: CoachMyProfileViewModel
  @State private var selectedTab: CoachTab = .today

  @MainActor
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
    studentProfiles: (any OnboardingProfileReading)? = nil,
    videoQueue: (any CoachVideoQueueRepository)? = nil,
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
    let resolvedProfiles = studentProfiles ?? InMemoryCoachStudentProfileReader()
    detailContext = CoachStudentDetailContext(
      plans: studentPlans,
      trainingLogs: studentLogs,
      feedback: feedback,
      profiles: resolvedProfiles,
      videos: studentVideos,
      readiness: readiness,
      familyMapProvider: familyMapProvider,
      planning: repository,
      draftStore: draftStore
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

  public var body: some View {
    TabView(selection: $selectedTab) {
      CoachDashboardView(
        attentionCount: rosterViewModel.pendingAttentionCount,
        pendingCount: queueViewModel.pendingCount,
        context: detailContext,
        rows: rosterViewModel.rows,
        onOpenReceiving: { selectedTab = .receiving },
        onOpenRoster: { selectedTab = .students }
      )
      .tag(CoachTab.today)
      .tabItem {
        Label("今日", systemImage: "house")
      }

      StudentRosterView(
        viewModel: rosterViewModel,
        context: detailContext
      )
      .tag(CoachTab.students)
      .tabItem {
        Label("学员", systemImage: "person.2")
      }
      // 待关注学员 (新学员 pending 计数已拆到「接收」tab, spec 033 D1).
      .badge(rosterViewModel.pendingAttentionCount)

      CoachPlanningHomeView(context: detailContext)
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
        onAccepted: { await rosterViewModel.refresh() }
      )
      .tag(CoachTab.receiving)
      .tabItem {
        Label("接收", systemImage: "tray")
      }
      // 收件箱红点 = 新学员 + 待反馈视频(spec 042).
      .badge(queueViewModel.pendingCount + videoQueueViewModel.pendingCount)

      CoachMyProfileView(viewModel: profileViewModel, inviteCodes: inviteCodes)
        .tag(CoachTab.profile)
        .tabItem {
          Label("我的", systemImage: "person")
        }
    }
    .task {
      await rosterViewModel.loadIfNeeded()
      await queueViewModel.loadIfNeeded()
      await videoQueueViewModel.loadIfNeeded()
    }
    .tint(Color.MeetPR.brandRed)
  }
}

private enum CoachTab: Hashable {
  case today
  case students
  case planning
  case receiving
  case profile
}
