import Analytics
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct StudentRootView: View {
  private let studentID: UUID
  private let canShiftPlanDays: Bool
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let e1rm: any E1RMRepository
  private let readiness: any ReadinessRepository
  private let videoUploads: VideoUploadServices
  private let onboarding: any OnboardingRepository
  private let onLogout: (@MainActor () async -> Void)?
  private let account: (any AccountRepository)?
  @State private var feedbackViewModel: FeedbackInboxViewModel
  @State private var evaluationSummaryViewModel: StudentEvaluationSummaryViewModel
  @State private var selectedTab: StudentTab = .today
  @State private var pendingPRCount = 0
  /// Bumped whenever 今日 becomes active so the home screen reloads data logged
  /// in other tabs (see DashboardView.todayReloadToken).
  @State private var todayReloadToken = 0
  /// Bumped when the home CTA opens the 训练 tab, so it lands on today rather
  /// than a previously-browsed day (see TodayWorkoutView.jumpToTodayToken).
  @State private var trainingJumpToken = 0
  @State private var planRevision = 0
  @State private var nextWorkoutSource: WorkoutSource?
  @State private var workoutStartedAt: Date?

  public init() {
    let plan = StudentDemoSeed.makePlanView()
    let store = StudentRootDemoPlanStore(studentID: StudentDemoSeed.studentID, plan: plan)
    self.init(
      studentID: StudentDemoSeed.studentID,
      canShiftPlanDays: true,
      plans: InMemoryStudentPlanRepository(store: store),
      logs: InMemoryStudentTrainingLogRepository(
        seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
      ),
      feedback: InMemoryStudentFeedbackRepository(
        seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
      ),
      e1rm: InMemoryE1RMRepository(
        seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID),
        seedPRs: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
      ),
      readiness: InMemoryReadinessRepository(
        seed: StudentDemoSeed.makeReadinessHistory(studentID: StudentDemoSeed.studentID)
      )
    )
  }

  public init(
    studentID: UUID = StudentDemoSeed.studentID,
    canShiftPlanDays: Bool = false,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    e1rm: any E1RMRepository = LocalE1RMRepository(),
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    videoUploads: VideoUploadServices? = nil,
    onboarding: (any OnboardingRepository)? = nil,
    evaluationSummaries: (any EvaluationSummaryRepository)? = nil,
    summaryReadStore: (any EvaluationSummaryReadStoring)? = nil,
    onLogout: (@MainActor () async -> Void)? = nil,
    account: (any AccountRepository)? = nil
  ) {
    self.studentID = studentID
    self.canShiftPlanDays = canShiftPlanDays
    self.plans = plans
    self.logs = logs
    self.e1rm = e1rm
    self.readiness = readiness
    self.videoUploads = videoUploads ?? .demo()
    self.onLogout = onLogout
    self.account = account
    let resolvedOnboarding =
      onboarding
      ?? InMemoryOnboardingRepository(
        studentId: studentID,
        seed: StudentDemoSeed.makeOnboardingProfile(studentID: studentID)
      )
    self.onboarding = resolvedOnboarding
    self._feedbackViewModel = State(
      initialValue: FeedbackInboxViewModel(repository: feedback)
    )
    self._evaluationSummaryViewModel = State(
      initialValue: StudentEvaluationSummaryViewModel(
        summaries: evaluationSummaries ?? InMemoryEvaluationSummaryRepository(),
        plans: plans,
        readStore: summaryReadStore ?? UserDefaultsEvaluationSummaryReadStore()
      )
    )
  }

  public var body: some View {
    studentTabs
  }

  private var studentTabs: some View {
    TabView(selection: $selectedTab) {
      // 今日 — student home (merges the old 仪表盘 + 计划; feedback now inlines
      // here + full history under 成长, so there is no separate 反馈 tab).
      DashboardView(
        studentID: studentID,
        canShiftPlanDays: canShiftPlanDays,
        plans: plans,
        logs: logs,
        onboarding: onboarding,
        e1rm: e1rm,
        feedbackViewModel: feedbackViewModel,
        evaluationSummaryViewModel: evaluationSummaryViewModel,
        onStartWorkout: {
          nextWorkoutSource = .dashboard
          trainingJumpToken += 1
          selectedTab = .training
        },
        onSeeAllFeedback: { selectedTab = .growth },
        todayReloadToken: todayReloadToken,
        onPlanChanged: { planRevision += 1 }
      )
      .tag(StudentTab.today)
      .tabItem {
        Label("今日", systemImage: "house")
      }

      TodayWorkoutView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding, readiness: readiness, videoUploads: videoUploads,
        jumpToTodayToken: trainingJumpToken,
        planRevision: planRevision,
        workoutStartedAt: $workoutStartedAt
      )
      .tag(StudentTab.training)
      .tabItem {
        Label("训练", systemImage: "dumbbell.fill")
      }

      // 成长 — e1RM growth + full training history + coach-feedback history all
      // live here (the 历史 tab folds in; assembled fully in a later slice).
      TrainingHistoryView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding,
        feedbackViewModel: feedbackViewModel
      )
      .tag(StudentTab.growth)
      .tabItem {
        Label("成长", systemImage: "chart.line.uptrend.xyaxis")
      }

      MyProfileView(
        studentID: studentID,
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding,
        evaluationSummaryViewModel: evaluationSummaryViewModel,
        onLogout: onLogout,
        account: account,
        logs: logs
      )
      .tag(StudentTab.profile)
      .tabItem {
        Label("我的", systemImage: "person")
      }
      // PR acknowledgements + unread evaluation summary red dot (spec 033 D7).
      // Feedback unread now surfaces via the 今日 notification bell, not a tab badge.
      .badge(pendingPRCount + evaluationSummaryViewModel.unreadBadgeCount)
    }
    .task {
      Analytics.shared.screen(.dashboard)
      if feedbackViewModel.state == .idle {
        await feedbackViewModel.load(studentID: studentID)
      }
      await evaluationSummaryViewModel.load(studentID: studentID)
      pendingPRCount = (try? await e1rm.unacknowledgedPRs(studentId: studentID).count) ?? 0
    }
    .onChange(of: selectedTab) { _, newTab in
      if newTab == .today { todayReloadToken += 1 }
      switch newTab {
      case .today:
        Analytics.shared.screen(.dashboard)
      case .training:
        workoutStartedAt = Date()
        Analytics.shared.screen(.todayWorkout)
        Analytics.shared.workoutLogStarted(source: nextWorkoutSource ?? .calendar)
        nextWorkoutSource = nil
      case .growth:
        Analytics.shared.screen(.progressHistory)
      case .profile:
        Analytics.shared.screen(.account)
      }
    }
    .tint(Color.MeetPR.brandRed)
  }
}

private enum StudentTab: Hashable {
  case today
  case training
  case growth
  case profile
}

private actor StudentRootDemoPlanStore: StudentPlanStore {
  private let studentID: UUID
  private let plan: StudentPlanView

  init(studentID: UUID, plan: StudentPlanView) {
    self.studentID = studentID
    self.plan = plan
  }

  func savePublishedProjection(_ projection: StudentPlanView, forStudent studentID: UUID) async {}

  func getPublishedProjection(forStudent studentID: UUID) async -> StudentPlanView? {
    studentID == self.studentID ? plan : nil
  }
}
