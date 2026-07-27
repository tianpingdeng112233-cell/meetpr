// swiftlint:disable file_length
import Analytics
import ChatUI
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

private enum LaunchMorphPhase: Equatable {
  case idle
  case exitingDashboard
  case awaitingDestinationFrame
  case morphing
  case fadingGhost
}

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
  @State private var trainingAutoStartToken = 0
  @State private var launchHeroRevealToken = 0
  @State private var planRevision = 0
  @State private var nextWorkoutSource: WorkoutSource?
  @State private var workoutStartedAt: Date?
  @State private var pendingImportedHistoryReview: PendingImportedHistoryReview?
  @State private var importedHistoryReviewQueue: [PendingImportedHistoryReview] = []
  @State private var importedHistoryRefreshToken = 0
  @State private var tabHostStore = StudentTabHostStore()
  @State private var dashboardCTAFrame = CGRect.zero
  @State private var trainingHeroFrame = CGRect.zero
  @State private var rootGlobalFrame = CGRect.zero
  @State private var launchSourceFrame: CGRect?
  @State private var launchMorphProgress = 0.0
  @State private var launchGhostFadeProgress = 0.0
  @State private var dashboardExitProgress = 0.0
  @State private var launchDestinationOpacity = 1.0
  @State private var revealsLaunchTarget = true
  @State private var launchMorphPhase: LaunchMorphPhase = .idle
  @State private var launchTask: Task<Void, Never>?
  @State private var launchCompletionTask: Task<Void, Never>?
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    let shell = StudentTabShellPresentation(selection: selectedTab)
    return ZStack {
      DashboardView(
        studentID: studentID,
        canShiftPlanDays: canShiftPlanDays,
        plans: plans,
        logs: logs,
        onboarding: onboarding,
        e1rm: e1rm,
        feedbackViewModel: feedbackViewModel,
        notifications: notifications,
        onStartWorkout: startWorkoutFromDashboard,
        onStartWorkoutFrameChange: { dashboardCTAFrame = $0 },
        isStartWorkoutHidden: launchSourceFrame != nil,
        onOpenPlanNotification: openPlanNotification,
        todayReloadToken: todayReloadToken + importedHistoryRefreshToken,
        onPlanChanged: { planRevision += 1 }
      )
      .studentTabLayer(shell.layer(for: .today), store: tabHostStore)
      .modifier(MeetPRLaunchExitModifier(progress: dashboardExitProgress))

      TodayWorkoutView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding, readiness: readiness,
        restTimerSettings: restTimerSettings, videoUploads: videoUploads,
        isActive: selectedTab == .training,
        jumpToTodayToken: trainingJumpToken,
        autoStartToken: trainingAutoStartToken,
        isLaunchTargetHidden: launchSourceFrame != nil && !revealsLaunchTarget,
        launchHeroRevealToken: launchHeroRevealToken,
        planRevision: planRevision,
        workoutStartedAt: $workoutStartedAt,
        notifications: notifications,
        onOpenPlanNotification: openPlanNotification,
        onHeroFrameChange: updateTrainingHeroFrame,
        onReturnToToday: { selectedTab = .today }
      )
      .studentTabLayer(shell.layer(for: .training), store: tabHostStore)
      .opacity(
        launchSourceFrame != nil && selectedTab == .training
          ? launchDestinationOpacity
          : 1
      )

      TrainingHistoryView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding,
        feedbackViewModel: feedbackViewModel,
        importedHistoryRefreshToken: importedHistoryRefreshToken,
        onImportedHistoryRefresh: { await runImportedHistoryBackfill() },
        notifications: notifications,
        onOpenPlanNotification: openPlanNotification
      )
      .studentTabLayer(shell.layer(for: .growth), store: tabHostStore)

      MyProfileView(
        studentID: studentID,
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding,
        readiness: readiness,
        onLogout: onLogout,
        account: account,
        logs: logs,
        restTimerSettings: restTimerSettings,
        notifications: notifications,
        onOpenPlanNotification: openPlanNotification,
        onOpenGrowth: { selectedTab = .growth }
      )
      .studentTabLayer(shell.layer(for: .profile), store: tabHostStore)

      if let launchSourceFrame {
        let launchDestinationFrame =
          trainingHeroFrame.width > 0 && trainingHeroFrame.height > 0
          ? trainingHeroFrame
          : launchSourceFrame
        MeetPRLaunchMorphOverlay(
          source: launchSourceFrame,
          destination: launchDestinationFrame,
          rootOrigin: rootGlobalFrame.origin,
          progress: launchMorphProgress,
          fadeProgress: launchGhostFadeProgress
        )
        .zIndex(20)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .global)
    } action: { frame in
      rootGlobalFrame = frame
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      MeetPRTabBar(
        selection: $selectedTab,
        items: [
          MeetPRTabBarItem(id: .today, title: "今日", icon: .today),
          MeetPRTabBarItem(id: .training, title: "训练", icon: .training),
          MeetPRTabBarItem(id: .growth, title: "成长", icon: .growth),
          MeetPRTabBarItem(
            id: .profile,
            title: "我的",
            icon: .profile,
            badge: pendingPRCount
          ),
        ]
      )
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
      handleTabSelectionChange(newTab)
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
    .onChange(of: reduceMotion) { _, newValue in
      guard newValue, launchMorphPhase != .idle else { return }
      finishLaunchForReducedMotion()
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
      cancelLaunchTransition()
    }
    .importedHistoryReviewAlert(
      review: $pendingImportedHistoryReview,
      onAnswer: answerImportedHistoryReview
    )
  }

  var hasNotificationCoordinator: Bool {
    notifications != nil
  }

  private func openPlanNotification() {
    trainingJumpToken += 1
    selectedTab = StudentNotificationRoute.plan.targetTab(from: selectedTab)
  }

  private func startWorkoutFromDashboard() {
    // Ignore repeated activation until the current launch has either
    // completed or been explicitly cancelled by navigation/reduced motion.
    guard launchMorphPhase == .idle else { return }

    nextWorkoutSource = .dashboard
    trainingJumpToken += 1

    guard !reduceMotion,
      dashboardCTAFrame.width > 0,
      dashboardCTAFrame.height > 0
    else {
      trainingAutoStartToken += 1
      selectedTab = .training
      return
    }

    cancelLaunchTasks()
    launchSourceFrame = dashboardCTAFrame
    trainingHeroFrame = .zero
    launchMorphProgress = 0
    launchGhostFadeProgress = 0
    dashboardExitProgress = 0
    launchDestinationOpacity = 0
    revealsLaunchTarget = false
    launchMorphPhase = .exitingDashboard

    // motion/01 line 92: old screen uses a 200ms quadratic sink/fade.
    withAnimation(.linear(duration: MeetPRMotion.launchExitDuration)) {
      dashboardExitProgress = 1
    }

    launchTask = Task { @MainActor in
      // motion/01 lines 93-112: destination is mounted after exactly 140ms.
      try? await Task.sleep(for: .seconds(MeetPRMotion.launchSwitchDelay))
      guard !Task.isCancelled else { return }
      // Auto-start while the training layer is still inactive, then open the
      // destination-frame gate. The first accepted geometry is therefore the
      // recording hero, never the pre-start list hero.
      trainingAutoStartToken += 1
      launchMorphPhase = .awaitingDestinationFrame
      selectedTab = .training
      // motion/01 line 99: destination screen fades linearly for 280ms.
      withAnimation(.linear(duration: MeetPRMotion.launchDestinationFadeDuration)) {
        launchDestinationOpacity = 1
      }
    }
  }

  private func updateTrainingHeroFrame(_ frame: CGRect) {
    guard launchMorphPhase == .awaitingDestinationFrame,
      frame.width > 0,
      frame.height > 0
    else {
      return
    }

    // Lock the first recording-hero frame for the entire morph. Subsequent
    // layout callbacks cannot move the target underneath the running tween.
    trainingHeroFrame = frame
    beginLaunchMorph()
  }

  private func beginLaunchMorph() {
    guard launchSourceFrame != nil,
      selectedTab == .training,
      trainingHeroFrame.width > 0,
      trainingHeroFrame.height > 0,
      launchMorphPhase == .awaitingDestinationFrame
    else {
      return
    }

    launchMorphPhase = .morphing
    // motion/01 lines 100-105: a linear clock feeds exact easeOutCubic for
    // 420ms so position, size and radius share one mathematical curve.
    withAnimation(.linear(duration: MeetPRMotion.launchMorphDuration)) {
      launchMorphProgress = 1
    }

    launchCompletionTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(MeetPRMotion.launchMorphDuration))
      guard !Task.isCancelled else { return }
      launchMorphPhase = .fadingGhost
      revealsLaunchTarget = true
      launchHeroRevealToken += 1
      // motion/01 line 110: the gold ghost fades for 200ms while hero
      // children start their 55ms-staggered reveal.
      withAnimation(.linear(duration: MeetPRMotion.launchGhostFadeDuration)) {
        launchGhostFadeProgress = 1
      }
      try? await Task.sleep(for: .seconds(MeetPRMotion.launchGhostFadeDuration))
      guard !Task.isCancelled else { return }
      resetLaunchTransition()
    }
  }

  private func resetLaunchTransition() {
    var transaction = Transaction()
    transaction.animation = nil
    withTransaction(transaction) {
      launchMorphPhase = .idle
      launchSourceFrame = nil
      trainingHeroFrame = .zero
      launchMorphProgress = 0
      launchGhostFadeProgress = 0
      dashboardExitProgress = 0
      launchDestinationOpacity = 1
      revealsLaunchTarget = true
    }
  }

  private func handleTabSelectionChange(_ newTab: StudentTab) {
    guard launchMorphPhase != .idle else { return }
    let isExpectedDestinationSwitch =
      newTab == .training
      && launchMorphPhase == .awaitingDestinationFrame
    guard !isExpectedDestinationSwitch else {
      beginLaunchMorph()
      return
    }
    cancelLaunchTransition()
  }

  private func finishLaunchForReducedMotion() {
    let stillNeedsAutoStart = launchMorphPhase == .exitingDashboard
    cancelLaunchTasks()
    if stillNeedsAutoStart {
      trainingAutoStartToken += 1
    }
    resetLaunchTransition()
    selectedTab = .training
  }

  private func cancelLaunchTransition() {
    cancelLaunchTasks()
    resetLaunchTransition()
  }

  private func cancelLaunchTasks() {
    launchTask?.cancel()
    launchCompletionTask?.cancel()
    launchTask = nil
    launchCompletionTask = nil
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
