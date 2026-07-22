import Analytics
import ChatUI
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
  private let importedHistoryBackfill: ImportedHistoryBackfill
  private let onLogout: (@MainActor () async -> Void)?
  private let account: (any AccountRepository)?
  private let restTimerSettings: any StudentRestTimerSettingsStoring
  @State private var feedbackViewModel: FeedbackInboxViewModel
  @State private var evaluationSummaryViewModel: StudentEvaluationSummaryViewModel
  @State private var notifications: StudentNotificationsCoordinator?
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
  @State private var pendingImportedHistoryReview: PendingImportedHistoryReview?
  @State private var importedHistoryReviewQueue: [PendingImportedHistoryReview] = []
  @State private var importedHistoryRefreshToken = 0
  @State private var evaluationNavigationPulse = 0
  @Environment(\.scenePhase) private var scenePhase

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
      ),
      importedHistoryReviews: InMemoryImportedHistoryReviewStore()
    )
  }

  // swiftlint:disable:next function_body_length
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
    account: (any AccountRepository)? = nil,
    importedHistoryReviews: (any ImportedHistoryReviewStoring)? = nil,
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    allowsChat: Bool = false,
    chat: (any ChatRepository)? = nil,
    currentUserID: UUID? = nil,
    inbox: ChatInboxViewModel? = nil,
    sendCoordinator: ChatSendCoordinator? = nil,
    activeCoach: ActiveCoachContext? = nil,
    onBindingInvalidated: @escaping @Sendable () async -> Void = {}
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
    self.restTimerSettings = restTimerSettings
    let resolvedOnboarding =
      onboarding
      ?? InMemoryOnboardingRepository(
        studentId: studentID,
        seed: StudentDemoSeed.makeOnboardingProfile(studentID: studentID)
      )
    self.onboarding = resolvedOnboarding
    let resolvedImportedHistoryReviews: any ImportedHistoryReviewStoring
    if let importedHistoryReviews {
      resolvedImportedHistoryReviews = importedHistoryReviews
    } else if plans is InMemoryStudentPlanRepository {
      resolvedImportedHistoryReviews = InMemoryImportedHistoryReviewStore()
    } else {
      resolvedImportedHistoryReviews = LocalImportedHistoryReviewStore()
    }
    self.importedHistoryBackfill = ImportedHistoryBackfill(
      logs: logs,
      onboarding: resolvedOnboarding,
      plans: plans,
      catalogReader: plans as? any ExerciseCatalogReading,
      e1rm: e1rm,
      reviews: resolvedImportedHistoryReviews
    )
    let feedbackViewModel = FeedbackInboxViewModel(repository: feedback)
    let evaluationSummaryViewModel = StudentEvaluationSummaryViewModel(
      summaries: evaluationSummaries ?? InMemoryEvaluationSummaryRepository(),
      plans: plans,
      readStore: summaryReadStore ?? UserDefaultsEvaluationSummaryReadStore()
    )
    self._feedbackViewModel = State(initialValue: feedbackViewModel)
    self._evaluationSummaryViewModel = State(initialValue: evaluationSummaryViewModel)

    let chatContext: StudentChatContext?
    if allowsChat,
      let chat,
      let currentUserID,
      let inbox,
      let sendCoordinator
    {
      chatContext = StudentChatContext(
        repository: chat,
        currentUserID: currentUserID,
        inbox: inbox,
        sendCoordinator: sendCoordinator
      )
    } else {
      chatContext = nil
    }

    if allowsChat {
      self._notifications = State(
        initialValue: StudentNotificationsCoordinator(
          plans: plans,
          feedback: feedbackViewModel,
          evaluation: evaluationSummaryViewModel,
          activeCoach: activeCoach,
          chatContext: chatContext,
          onBindingInvalidated: onBindingInvalidated
        )
      )
    } else {
      self._notifications = State(initialValue: nil)
    }
  }

  public var body: some View {
    studentTabs
  }

}

extension StudentRootView {
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
        notifications: notifications,
        evaluationNavigationPulse: evaluationNavigationPulse,
        onStartWorkout: {
          nextWorkoutSource = .dashboard
          trainingJumpToken += 1
          selectedTab = .training
        },
        onSeeAllFeedback: { selectedTab = .growth },
        onOpenEvaluation: openEvaluationNotification,
        todayReloadToken: todayReloadToken + importedHistoryRefreshToken,
        onPlanChanged: { planRevision += 1 }
      )
      .tag(StudentTab.today)
      .tabItem {
        Label("今日", systemImage: "house")
      }

      TodayWorkoutView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding, readiness: readiness,
        restTimerSettings: restTimerSettings, videoUploads: videoUploads,
        jumpToTodayToken: trainingJumpToken,
        planRevision: planRevision,
        workoutStartedAt: $workoutStartedAt,
        notifications: notifications,
        onOpenPlanNotification: openPlanNotification,
        onOpenFeedbackNotification: openFeedbackNotification,
        onOpenEvaluationNotification: openEvaluationNotification
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
        feedbackViewModel: feedbackViewModel,
        importedHistoryRefreshToken: importedHistoryRefreshToken,
        onImportedHistoryRefresh: { await runImportedHistoryBackfill() },
        notifications: notifications,
        onOpenPlanNotification: openPlanNotification,
        onOpenFeedbackNotification: openFeedbackNotification,
        onOpenEvaluationNotification: openEvaluationNotification
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
        logs: logs,
        restTimerSettings: restTimerSettings,
        notifications: notifications,
        onOpenPlanNotification: openPlanNotification,
        onOpenFeedbackNotification: openFeedbackNotification,
        onOpenEvaluationNotification: openEvaluationNotification
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
      if let notifications {
        await notifications.loadIfNeeded(studentID: studentID)
        if scenePhase == .active {
          notifications.startChatPolling()
        }
      } else {
        if feedbackViewModel.state == .idle {
          await feedbackViewModel.load(studentID: studentID)
        }
        await evaluationSummaryViewModel.load(studentID: studentID)
      }
      pendingPRCount = (try? await e1rm.unacknowledgedPRs(studentId: studentID).count) ?? 0
      await runImportedHistoryBackfill()
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
        Task { await runImportedHistoryBackfill() }
      case .profile:
        Analytics.shared.screen(.account)
      }
    }
    .onChange(of: scenePhase) { _, phase in
      guard let notifications else { return }
      if phase == .active {
        notifications.startChatPolling()
        Task { await notifications.reload(studentID: studentID) }
      } else {
        notifications.stopChatPolling()
      }
    }
    .onDisappear {
      notifications?.stopChatPolling()
    }
    .importedHistoryReviewAlert(
      review: $pendingImportedHistoryReview,
      onAnswer: answerImportedHistoryReview
    )
    .tint(Color.MeetPR.brandRed)
  }

  var hasNotificationCoordinator: Bool {
    notifications != nil
  }

  private func openPlanNotification() {
    trainingJumpToken += 1
    selectedTab = StudentNotificationRoute.plan.targetTab(from: selectedTab)
  }

  private func openFeedbackNotification() {
    selectedTab = StudentNotificationRoute.feedback.targetTab(from: selectedTab)
  }

  private func openEvaluationNotification() {
    selectedTab = StudentNotificationRoute.evaluation.targetTab(from: selectedTab)
    evaluationNavigationPulse += 1
  }

  @MainActor
  private func runImportedHistoryBackfill() async {
    guard let result = try? await importedHistoryBackfill.backfill(studentID: studentID) else {
      return
    }
    importedHistoryReviewQueue = ImportedHistoryReviewQueue.appendingUnique(
      result.pendingReviews,
      current: pendingImportedHistoryReview,
      waiting: importedHistoryReviewQueue
    )
    presentNextImportedHistoryReview()
    if result.newImportedPointCount > 0 {
      importedHistoryRefreshToken += 1
    }
  }

  @MainActor
  private func answerImportedHistoryReview(
    _ review: PendingImportedHistoryReview,
    decision: ImportedHistoryReviewDecision
  ) async {
    try? await importedHistoryBackfill.answer(review, decision: decision)
    importedHistoryReviewQueue.removeAll { $0.id == review.id }
    if pendingImportedHistoryReview?.id == review.id {
      pendingImportedHistoryReview = nil
    }
    presentNextImportedHistoryReview()
    importedHistoryRefreshToken += 1
  }

  private func presentNextImportedHistoryReview() {
    guard pendingImportedHistoryReview == nil else { return }
    let next = ImportedHistoryReviewQueue.takingNext(from: importedHistoryReviewQueue)
    pendingImportedHistoryReview = next.current
    importedHistoryReviewQueue = next.waiting
  }
}
