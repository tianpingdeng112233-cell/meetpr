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

struct LaunchDestinationFrameLatch: Equatable {
  private(set) var frame: CGRect?

  mutating func arm() {
    frame = nil
  }

  mutating func capture(_ candidate: CGRect) -> Bool {
    guard frame == nil, candidate.width > 0, candidate.height > 0 else { return false }
    frame = candidate
    return true
  }

  mutating func reset() {
    frame = nil
  }
}

@available(iOS 17.0, macOS 14.0, *)
public struct StudentRootView: View {
  private let studentID: UUID
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
  private let restTimerActivityController: any RestTimerActivityControlling
  @Binding private var pushRoute: PushRouteIntent?
  @State private var feedbackViewModel: FeedbackInboxViewModel
  @State private var evaluationSummaryViewModel: StudentEvaluationSummaryViewModel
  @State private var notifications: StudentNotificationsCoordinator?
  @State private var selectedTab: StudentTab = .today
  /// Bumped whenever 今日 becomes active so the home screen reloads data logged
  /// in other tabs (see DashboardView.todayReloadToken).
  @State private var todayReloadToken = 0
  @State private var todayVolatileReloadToken = 0
  @State private var todayRefreshThrottle = StudentTodayRefreshThrottle()
  @State private var trainingPlanRefreshTrigger = StudentTrainingPlanRefreshTrigger()
  /// Bumped when the home CTA opens the 训练 tab, so it lands on today rather
  /// than a previously-browsed day (see TodayWorkoutView.jumpToTodayToken).
  @State private var trainingJumpToken = 0
  @State private var uploadFailureDestination: UploadFailureDestination?
  @State private var uploadFailureNavigationToken = 0
  @State private var workoutPlanHandoff: TodayWorkoutPlanHandoff?
  @State private var launchHeroRevealToken = 0
  @State private var planRevision = 0
  @State private var planProjectionUpdate: StudentPlanView?
  @State private var nextWorkoutSource: WorkoutSource?
  @State private var workoutStartedAt: Date?
  @State private var pendingImportedHistoryReview: PendingImportedHistoryReview?
  @State private var importedHistoryReviewQueue: [PendingImportedHistoryReview] = []
  @State private var importedHistoryRefreshToken = 0
  @State private var tabHostStore = StudentTabHostStore()
  @State private var dashboardCTAFrame = CGRect.zero
  @State private var launchDestinationFrameLatch = LaunchDestinationFrameLatch()
  @State private var heroFrameRequestToken = 0
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
    let logs = InMemoryStudentTrainingLogRepository(
      seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
    )
    self.init(
      studentID: StudentDemoSeed.studentID,
      plans: InMemoryStudentPlanRepository(store: store),
      logs: logs,
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
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    // Optional-with-nil (not `= InMemoryVideoMarkerRepository()`): a public
    // default argument is emitted into the CALLER, and app-level targets that
    // don't link RepositoryContracts directly would fail to link the symbol.
    videoMarkers: (any VideoMarkerRepository)? = nil,
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
    restTimerActivityController: any RestTimerActivityControlling =
      NoOpRestTimerActivityController(),
    allowsChat: Bool = false,
    chat: (any ChatRepository)? = nil,
    currentUserID: UUID? = nil,
    inbox: ChatInboxViewModel? = nil,
    sendCoordinator: ChatSendCoordinator? = nil,
    activeCoach: ActiveCoachContext? = nil,
    onBindingInvalidated: @escaping @Sendable () async -> Void = {},
    pushRoute: Binding<PushRouteIntent?> = .constant(nil)
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.e1rm = e1rm
    self.readiness = readiness
    let resolvedVideoUploads = videoUploads ?? .demo()
    self.videoUploads = resolvedVideoUploads
    // Every student-side logout path (profile, account security, bind gate,
    // evaluation gate) funnels through this closure, so clearing reminders
    // here covers them all; reconcile-on-appear handles logouts that bypass
    // StudentKit entirely (e.g. credential expiry).
    if let onLogout {
      self.onLogout = { @MainActor in
        await TrainingReminderServices.live.scheduler.clear()
        await onLogout()
      }
    } else {
      self.onLogout = nil
    }
    self.account = account
    self.restTimerSettings = restTimerSettings
    self.restTimerActivityController = restTimerActivityController
    self._pushRoute = pushRoute
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
    let feedbackViewModel = FeedbackInboxViewModel(
      repository: feedback,
      markerRepository: videoMarkers ?? InMemoryVideoMarkerRepository()
    )
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
        sendCoordinator: sendCoordinator,
        setRefSharing: TodaySetRefSharingSource(
          studentID: studentID,
          plans: plans,
          logs: logs,
          videoManager: resolvedVideoUploads.manager
        ).sharingContext()
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
        todayVolatileReloadToken: todayVolatileReloadToken,
        planProjectionUpdate: planProjectionUpdate,
        onFullReload: {
          todayRefreshThrottle.recordFullRefresh(at: Date())
        },
        onPlanChanged: propagatePlanProjection,
        pushedConversationID: pushedConversationIDBinding
      )
      .studentTabLayer(shell.layer(for: .today), store: tabHostStore)
      .modifier(MeetPRLaunchExitModifier(progress: dashboardExitProgress))

      TodayWorkoutView(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding, readiness: readiness,
        restTimerSettings: restTimerSettings,
        restTimerActivityController: restTimerActivityController,
        videoUploads: videoUploads,
        planHandoff: workoutPlanHandoff,
        jumpToTodayToken: trainingJumpToken,
        uploadFailureDestination: uploadFailureDestination,
        uploadFailureNavigationToken: uploadFailureNavigationToken,
        isLaunchTargetHidden: launchSourceFrame != nil && !revealsLaunchTarget,
        heroFrameRequestToken: heroFrameRequestToken,
        launchHeroRevealToken: launchHeroRevealToken,
        planRevision: planRevision,
        planProjectionUpdate: planProjectionUpdate,
        planRefreshRevision: trainingPlanRefreshTrigger.revision,
        workoutStartedAt: $workoutStartedAt,
        notifications: notifications,
        onOpenPlanNotification: openPlanNotification,
        onPlanChanged: propagatePlanProjection,
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
        onOpenPlanNotification: openPlanNotification,
        onOpenToday: { selectedTab = .today }
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
        onOpenPlanNotification: openPlanNotification
      )
      .studentTabLayer(shell.layer(for: .profile), store: tabHostStore)

      if let launchSourceFrame {
        let launchDestinationFrame = launchDestinationFrameLatch.frame ?? launchSourceFrame
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
          MeetPRTabBarItem(
            id: .today, title: StudentStrings.localized(.studentRootView001), icon: .today),
          MeetPRTabBarItem(
            id: .training, title: StudentStrings.localized(.studentRootView002), icon: .training),
          MeetPRTabBarItem(
            id: .growth, title: StudentStrings.localized(.studentRootView003), icon: .growth),
          MeetPRTabBarItem(
            id: .profile,
            title: StudentStrings.localized(.studentRootView004),
            icon: .profile,
            badge: 0
          ),
        ]
      )
    }
    .task {
      handlePushRoute(pushRoute)
      Analytics.shared.screen(.dashboard)
      await TrainingReminderBootstrap.reconcile(
        studentID: studentID,
        services: .live
      )
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
      await runImportedHistoryBackfill()
    }
    .task {
      for await destination in UploadFailureNavigation.shared.events {
        uploadFailureDestination = destination
        uploadFailureNavigationToken += 1
        selectedTab = .training
      }
    }
    .onChange(of: selectedTab) { _, newTab in
      handleTabSelectionChange(newTab)
      trainingPlanRefreshTrigger.handleTabSelection(newTab)
      if newTab == .today {
        switch todayRefreshThrottle.refreshWhenReturning(at: Date()) {
        case .full:
          todayReloadToken += 1
        case .volatileOnly:
          todayVolatileReloadToken += 1
        }
      }
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
    .onChange(of: pushRoute) { _, route in
      handlePushRoute(route)
    }
    .onChange(of: reduceMotion) { _, newValue in
      guard newValue, launchMorphPhase != .idle else { return }
      finishLaunchForReducedMotion()
    }
    .onChange(of: scenePhase) { _, phase in
      trainingPlanRefreshTrigger.handleScenePhase(phase)
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
    Task {
      let plan: StudentPlanView?
      do {
        plan = try await plans.refreshCurrentPlan(studentID: studentID)
      } catch {
        plan = try? await plans.fetchCurrentPlan(studentID: studentID)
      }
      forcePlanTreeReload()
      workoutPlanHandoff = plan.flatMap { plan in
        let sequence = StudentPlanSequence(days: plan.days)
        guard let day = sequence.cursorDay ?? sequence.orderedDays.last else { return nil }
        return TodayWorkoutPlanHandoff(plan: plan, dayID: day.id, existingLogs: [])
      }
      trainingJumpToken += 1
      selectedTab = StudentNotificationRoute.plan.targetTab(from: selectedTab)
    }
  }

  private func forcePlanTreeReload() {
    planProjectionUpdate = nil
    workoutPlanHandoff = nil
    planRevision += 1
    todayReloadToken += 1
  }

  private func propagatePlanProjection(_ plan: StudentPlanView) {
    planProjectionUpdate = plan
  }

  private func handlePushRoute(_ route: PushRouteIntent?) {
    guard let route else { return }
    switch route {
    case .chatMessage:
      // The current student shell has no standalone messages tab; its existing
      // inbox path presents the coach conversation from the 今日 tab.
      selectedTab = .today
    case .planShifted(let routeStudentID, _), .planShiftUndone(let routeStudentID, _),
      .planUpdated(let routeStudentID, _), .planPublished(let routeStudentID, _):
      pushRoute = nil
      guard routeStudentID == studentID,
        StudentNotificationRoute.route(for: route) == .plan
      else { return }
      if selectedTab == .training {
        trainingPlanRefreshTrigger.handlePushRoute(route)
      }
      openPlanNotification()
    case .missedTraining, .prCongrats, .videoPending, .bindRequest, .planShift:
      pushRoute = nil
    }
  }

  private var pushedConversationIDBinding: Binding<UUID?> {
    Binding(
      get: {
        guard case .chatMessage(let conversationID) = pushRoute else { return nil }
        return conversationID
      },
      set: { conversationID in
        guard conversationID == nil else { return }
        pushRoute = nil
      }
    )
  }

  private func startWorkoutFromDashboard(handoff: TodayWorkoutPlanHandoff?) {
    // Ignore repeated activation until the current launch has either
    // completed or been explicitly cancelled by navigation/reduced motion.
    guard launchMorphPhase == .idle else { return }

    nextWorkoutSource = .dashboard
    if let handoff {
      workoutPlanHandoff = handoff
    }
    trainingJumpToken += 1

    guard !reduceMotion,
      dashboardCTAFrame.width > 0,
      dashboardCTAFrame.height > 0
    else {
      selectedTab = .training
      return
    }

    cancelLaunchTasks()
    launchDestinationFrameLatch.arm()
    launchSourceFrame = dashboardCTAFrame
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
      // Open the destination-frame gate before mounting the training layer.
      // A new request token makes the actual destination hero republish: an
      // untouched day is a list, while a partially logged day is recording.
      launchMorphPhase = .awaitingDestinationFrame
      heroFrameRequestToken += 1
      selectedTab = .training
      // motion/01 line 99: destination screen fades linearly for 280ms.
      withAnimation(.linear(duration: MeetPRMotion.launchDestinationFadeDuration)) {
        launchDestinationOpacity = 1
      }
    }
  }

  private func updateTrainingHeroFrame(_ frame: CGRect) {
    guard launchMorphPhase == .awaitingDestinationFrame,
      launchDestinationFrameLatch.capture(frame)
    else { return }

    // The first frame from the newly requested current hero is the morph's
    // immutable geometry. Later layout callbacks cannot move its endpoint.
    beginLaunchMorph()
  }

  private func beginLaunchMorph() {
    guard launchSourceFrame != nil,
      selectedTab == .training,
      launchDestinationFrameLatch.frame != nil,
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
      launchDestinationFrameLatch.reset()
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
    cancelLaunchTasks()
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
