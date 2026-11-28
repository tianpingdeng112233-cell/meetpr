// swiftlint:disable file_length type_body_length
import Analytics
import ChatUI
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TodayWorkoutView: View {
  private let isVisible: Bool
  private let studentID: UUID
  private let restTimerSettings: any StudentRestTimerSettingsStoring
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let coachRPEReconciler: E1RMCoachRPEReconciler?
  private let planHandoff: TodayWorkoutPlanHandoff?
  private let initialDate: Date?
  private let jumpToTodayToken: Int
  private let uploadFailureDestination: UploadFailureDestination?
  private let uploadFailureNavigationToken: Int
  private let planRevision: Int
  private let planProjectionUpdate: StudentPlanView?
  private let planRefreshRevision: Int
  private var workoutStartedAt: Binding<Date?>
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onPlanChanged: (StudentPlanView) -> Void
  @Environment(BodyWeightEntryModel.self) private var weightEntry: BodyWeightEntryModel?
  @Environment(ProfileNavigation.self) private var profileNavigation: ProfileNavigation?
  @Environment(\.isStudentPresentationBlocked) private var ancestorPresentationBlocked
  @Environment(\.bindFirstRun) private var bindFirstRun
  @State private var childPresentationBlocked = false
  @State private var workoutModalIsPresented = false
  private let onOpenCoach: () -> Void

  @State private var restRingHeaderBottom: CGFloat = 0
  @State private var completionDockTop: CGFloat?
  @State private var viewModel: TodayWorkoutViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var replay: CompletedVideoReplayModel
  @State private var videoViewModel: VideoAttachmentViewModel
  @State private var handledUploadFailureToken = 0
  @State private var pendingUploadRetryDate: Date?
  @State private var showingCycleOutlook = false
  @State private var resumePrompt: WorkoutResumePrompt?
  @State private var resumeNotice: String?
  @State private var resumeNoticeTask: Task<Void, Never>?
  @State private var entryReady = true
  @State private var defaultEntry = true
  @State private var waitingResume: (prompt: WorkoutResumePrompt, date: Date)?
  private let resumeVisits = WorkoutResumeVisits()
  @State private var selectedDayID: UUID?
  @State private var previewDayID: UUID?
  @Environment(WorkoutKeypadSession.self) private var keypad: WorkoutKeypadSession?
  @State private var editing: EditingTarget?
  @State private var quickLogRoute: QuickLogRoute?
  @State private var quickLogToastWeekCode: String?
  @State private var quickLogToastTask: Task<Void, Never>?
  @State private var directCameraTarget: DirectCameraTarget?
  @State private var showingDirectCameraConsent = false
  @State private var pendingDirectCameraTarget: DirectCameraTarget?
  @State private var preparingVideoSetID: UUID?
  @State private var retryTargetSetLogID: UUID?
  @State private var showingReadinessSheet = false
  @State private var exerciseNoteSent = false
  @State private var exerciseNote: ExerciseRefV1?
  @Environment(ExerciseNoteNavigation.self) private var exerciseNavigation: ExerciseNoteNavigation?
  @State private var showingHistory = false
  @State private var historyViewModel: TrainingHistoryViewModel
  @State private var showingNotifications = false
  @State private var conversationID: UUID?
  @State private var setRefPickerRoute: SetRefPickerRoute?
  @State private var isPreparingSetRefPicker = false
  @State private var setRefEntryErrorMessage: String?
  @State private var reviewCompleted = false
  @State private var started = false
  @State private var gymDayToday = WorkoutDatePolicy.gymDayToday()
  @Environment(\.scenePhase) private var scenePhase
  @State private var collapsedExercises: [UUID: Bool] = [:]

  private let reviewStore: any SessionReviewStore = UserDefaultsSessionReviewStore()

  public init(
    studentID: UUID,
    isVisible: Bool = true,
    setSyncQueue: SetSyncQueue? = nil,
    date: Date? = nil,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    onboarding: (any OnboardingProfileReading)? = nil,
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    restTimerActivityController: any RestTimerActivityControlling =
      NoOpRestTimerActivityController(),
    videoUploads: VideoUploadServices? = nil,
    feedbackViewModel: FeedbackInboxViewModel? = nil,
    planHandoff: TodayWorkoutPlanHandoff? = nil,
    jumpToTodayToken: Int = 0,
    uploadFailureDestination: UploadFailureDestination? = nil,
    uploadFailureNavigationToken: Int = 0,
    planRevision: Int = 0,
    planProjectionUpdate: StudentPlanView? = nil,
    planRefreshRevision: Int = 0,
    workoutStartedAt: Binding<Date?> = .constant(nil),
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {},
    onPlanChanged: @escaping (StudentPlanView) -> Void = { _ in },
    onOpenCoach: @escaping () -> Void = {}
  ) {
    self.isVisible = isVisible
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    if let onboarding {
      self.coachRPEReconciler = E1RMCoachRPEReconciler(
        logs: logs,
        onboarding: onboarding,
        plans: plans,
        catalogReader: plans as? any ExerciseCatalogReading,
        e1rm: e1rm
      )
    } else {
      self.coachRPEReconciler = nil
    }
    self.restTimerSettings = restTimerSettings
    self.planHandoff = planHandoff
    self.initialDate = date
    self.jumpToTodayToken = jumpToTodayToken
    self.uploadFailureDestination = uploadFailureDestination
    self.uploadFailureNavigationToken = uploadFailureNavigationToken
    self.planRevision = planRevision
    self.planProjectionUpdate = planProjectionUpdate
    self.planRefreshRevision = planRefreshRevision
    self.workoutStartedAt = workoutStartedAt
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onPlanChanged = onPlanChanged
    self.onOpenCoach = onOpenCoach
    self._defaultEntry = State(initialValue: planHandoff?.dayID == nil && date == nil)
    self._selectedDayID = State(initialValue: planHandoff?.dayID)
    self._viewModel = State(
      initialValue: TodayWorkoutViewModel(
        plans: plans,
        logs: logs,
        e1rm: e1rm,
        setSyncQueue: setSyncQueue,
        onboarding: onboarding,
        restTimerSettings: restTimerSettings,
        restTimerActivityController: restTimerActivityController
      )
    )
    self._historyViewModel = State(initialValue: TrainingHistoryViewModel(plans: plans, logs: logs))
    self._readinessViewModel = State(initialValue: ReadinessCheckinViewModel(repo: readiness))
    let services = videoUploads ?? .demo()
    self._replay = State(
      initialValue: CompletedVideoReplayModel(services: services, feedback: feedbackViewModel))
    self._videoViewModel = State(
      initialValue: VideoAttachmentViewModel(manager: services.manager)
    )
  }

  init(
    studentID: UUID,
    date: Date,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    preloadedViewModel: TodayWorkoutViewModel,
    notifications: StudentNotificationsCoordinator? = nil,
    started: Bool = false
  ) {
    self.init(
      studentID: studentID,
      date: date,
      plans: plans,
      logs: logs,
      notifications: notifications
    )
    _viewModel = State(initialValue: preloadedViewModel)
    _started = State(initialValue: started)
  }

  public var body: some View {
    workoutContent
      .onChange(of: visitContext, initial: true) { _, context in
        checkResume(context)
      }
      .onChange(of: viewModel.planDays) { _, days in
        guard let prompt = resumePrompt, !viewModel.isCompletionMutationInFlight,
          !viewModel.allDayWriting, days.first(where: { $0.id == prompt.id })?.completedAt != nil
        else { return }
        resumePrompt = nil
        returnToCurrentDay()
      }
      .sheet(item: $resumePrompt, onDismiss: workoutModalDidDismiss) { prompt in
        let current = prompt.asOf(gymDayToday)
        WorkoutResumeSheet(
          prompt: current, lockedDate: viewModel.lockedResumeDate(dayID: prompt.id)
        ) { date in
          await finishResume(current, date: date)
        } onContinue: {
          resumeVisits.continueDay(
            student: studentID, plan: prompt.planID, day: prompt.id, today: gymDayToday)
          resumePrompt = nil
        }
      }
      .onPreferenceChange(TrainingPresentationBlockedKey.self) { childPresentationBlocked = $0 }
      .onChange(of: hasRequestedWorkoutModal, initial: true) { _, requested in
        if requested { workoutModalIsPresented = true }
      }
      .onPreferenceChange(RestRingHeaderBottomKey.self) { restRingHeaderBottom = $0 }
      .overlay {
        RestTimerOverlay(
          session: viewModel.restRing,
          available: isVisible && isEditable && viewModel.currentRestExercise != nil,
          hidden: keypad?.current != nil || editing != nil,
          hasOtherPresentation: restRingPresentationBlocked,
          seconds: viewModel.currentRestSeconds,
          exercise: viewModel.currentRestExercise?.displayExerciseName ?? "",
          headerBottom: restRingHeaderBottom, dockTop: completionDockTop)
      }
      .modifier(
        ExerciseNotePresentation(
          reference: $exerciseNote, onDismiss: workoutModalDidDismiss
        ) { reference in
          ExerciseNoteSheet(reference: reference) { note in
            guard let notifications, let chat = notifications.chatContext else { return false }
            let result = await notifications.openExerciseNoteConversation()
            guard case .opened(let id) = result else { return false }
            chat.sendCoordinator.sendExerciseNote(
              in: id, reference: reference, note: note,
              english: Locale.current.language.languageCode?.identifier == "en")
            exerciseNoteSent = true
            return true
          }
        }
      )
      .overlay(alignment: .top) {
        if exerciseNoteSent {
          Text(StudentStrings.localized(.allDaySent))
            .padding().background(Color.MeetPR.surfaceCard, in: .capsule)
            .task {
              try? await Task.sleep(for: .seconds(3))
              exerciseNoteSent = false
            }
        }
      }
      .onChange(of: safeHandoffBoundary) { _, _ in
        viewModel.invalidatePlanNavigation()
      }
      .onChange(of: exerciseNavigation?.reference) { _, reference in
        guard let reference else { return }
        Task {
          defer { exerciseNavigation?.reference = nil }
          do {
            guard let plan = try await plans.fetchCurrentPlan(studentID: studentID),
              let day = ExerciseNoteDayResolver.resolve(reference, days: plan.days)
            else {
              setRefEntryErrorMessage = StudentStrings.localized(.allDayUnavailable)
              return
            }
            defaultEntry = false
            selectedDayID = day.id
            await loadWorkout(for: day.id, preloadedPlan: plan)
          } catch {
            setRefEntryErrorMessage = StudentStrings.localized(.allDayUnavailable)
          }
        }
      }
  }

  // One initializer keeps all existing screen bindings and callbacks together.
  // swiftlint:disable:next function_body_length
  private func makeWorkoutScreen() -> TodayWorkoutScreen<TrainingWeekStrip> {
    TodayWorkoutScreen(
      content: screenContent,
      weekCode: weekCode,
      dayState: selectedDayState,
      reviewCompleted: reviewCompleted,
      unreadCount: notifications?.totalUnreadCount ?? 0,
      showsNotifications: false,
      coachName: notifications?.activeCoach?.coachDisplayName
        ?? StudentStrings.localized(.todayWorkoutView001),
      showsAskCoach: showsSetRefEntry,
      isPreparingAskCoach: isPreparingSetRefPicker,
      collapsedExercises: $collapsedExercises,
      sequenceContent: TrainingWeekStrip(
        days: viewModel.displayedPlan?.days ?? [], selectedDayID: displayedDayBinding,
        today: gymDayToday,
        previousPlan: viewModel.adjacentPlan(forward: false) == nil
          ? nil : { turnPlan(forward: false) },
        nextPlan: viewModel.adjacentPlan(forward: true) == nil ? nil : { turnPlan(forward: true) },
        isPlanPreview: viewModel.isPreviewingPlan),
      showsBackToToday: sequencePage.showsBackToToday,
      onBackToToday: returnToCurrentDay,
      onRefresh: {
        Task { await reloadCurrentDay() }
      },
      onHistory: { showingHistory = true },
      onReadiness: {
        showingReadinessSheet = true
      },
      onNotifications: {
        onOpenCoach()
      },
      onMessageCoach: {
        onOpenCoach()
      },
      onAskCoach: openSetRefPicker,
      onStart: {
        started = true
      },
      onQuickLog: openQuickLog,
      onEdit: openEditor,
      onVideoAction: openVideoAction,
      onComplete: completeTraining,
      accessoryViewModel: viewModel,
      accessoryPreviousLogs: viewModel.accessoryPreviousLogs,
      sequencePage: sequencePage,
      gymDayToday: gymDayToday,
      restTimerHeight: 0,
      completionDockTop: completionDockTop,
      videoFailureCount: videoFailurePresentation.failureCount,
      onRetryVideos: retryDayVideos,
      videoCompletion: videoCompletionPresentation,
      onExerciseNote: openExerciseNote,
      onRefreshAsync: { await reloadCurrentDay() },
      weightEntry: weightEntry, studentID: studentID,
      onEditMeet: { profileNavigation?.destination = .meet },
      emptyState: trainingEmptyState,
      showsCoach: notifications != nil,
      onEditProfile: { profileNavigation?.destination = .about },
      handoffSummary: viewModel.handoff?.plans.first { $0.id == viewModel.displayedPlan?.cycleID },
      previewDay: previewDay,
      showsHandoffNotice: viewModel.showsHandoffNotice && !viewModel.browsingPastPlan,
      onDismissHandoff: { viewModel.dismissHandoffNotice() },
      resumeNotice: resumeNotice,
      onCycleOutlook: viewModel.showsCycleOutlook ? { showingCycleOutlook = true } : nil

    )
  }

  // A separate opaque result bounds SwiftUI type checking of the presentation chain.
  // swiftlint:disable:next function_body_length
  private func workoutBase() -> some View {
    NavigationStack {
      makeWorkoutScreen()
        #if os(iOS)
          .toolbar(.hidden, for: .navigationBar)
        #endif
        .onChange(of: videoCompletionRevision) { _, _ in
          Task { await viewModel.receiveVideoCompletion() }
        }
        .navigationDestination(isPresented: $showingHistory) {
          AllHistoryScreen(viewModel: historyViewModel, studentID: studentID)
        }

    }
    .environment(replay)
    .environment(videoViewModel)
    .modifier(
      VideoMissingFileHost(
        model: videoViewModel, enabled: editing == nil,
        context: missingVideoContext,
        onDismiss: workoutModalDidDismiss,
        onRestored: {
          await videoViewModel.retryFailures(
            studentID: studentID, workout: viewModel, trainingDate: selectedTrainingDate)
        })
    )
    .modifier(CompletedVideoReplayHost(model: replay, onDismiss: workoutModalDidDismiss))
    .task { await replay.load(studentID: studentID) }
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 0) {
        if viewModel.isPreviewingPlan {
          PlanHandoffReturnDock(remaining: viewModel.remainingCurrentTrainingDays) {
            Task {
              await viewModel.returnToCurrentPlan(isSafe: { safeHandoffBoundary })
              selectedDayID = viewModel.currentDay?.id
            }
          }
        } else if case .workout(let presentation) = screenContent {
          let dockContent = presentation.completionDock(
            dayState: selectedDayState, showingHistory: showingHistory,
            waitingForVideos: videoCompletionPresentation?.waiting == true)
          if dockContent != .none {
            TrainingCompletionDock(
              content: dockContent,
              totalSets: presentation.exercises.flatMap(\.prescribedRows).count,
              onComplete: completeTraining,
              onUndoCompletion: {
                Task { _ = await viewModel.undoCurrentDayCompletion() }
              },
              onShowReview: { viewModel.completionPhase = .review },
              isUndoDisabled: viewModel.isCompletionMutationInFlight,
              coordinator: viewModel.setSyncCompletion,
              videoCompletion: videoCompletionPresentation, onRetryVideos: retryDayVideos
            )
            .onGeometryChange(for: CGFloat.self) {
              $0.frame(in: .global).minY
            } action: {
              completionDockTop = $0
            }
            .onDisappear { completionDockTop = nil }
          }
        }

      }
    }
  }

  private var workoutContent: some View {
    workoutBase()
      #if os(iOS)
        .fullScreenCover(item: $editing, onDismiss: workoutModalDidDismiss) { target in
          setEntry(for: target)
        }
      #else
        .sheet(item: $editing, onDismiss: workoutModalDidDismiss) { target in
          setEntry(for: target)
        }
      #endif
      #if os(iOS)
        .fullScreenCover(
          item: $quickLogRoute, onDismiss: workoutModalDidDismiss, content: quickLogSheet)
      #else
        .sheet(item: $quickLogRoute, onDismiss: workoutModalDidDismiss) { route in
          quickLogSheet(for: route)
        }
      #endif
      #if os(iOS)
        .fullScreenCover(
          item: $viewModel.completionPhase, onDismiss: workoutModalDidDismiss
        ) { phase in
          completionFlow(phase: phase)
        }
      #else
        .sheet(
          item: $viewModel.completionPhase, onDismiss: workoutModalDidDismiss,
          content: completionFlow)
      #endif
      .sheet(isPresented: $showingCycleOutlook, onDismiss: workoutModalDidDismiss) {
        CycleOutlookSheet(model: viewModel) { dayID in
          showingCycleOutlook = false
          defaultEntry = false
          TodayWorkoutSelectionResolver.selectCycleDay(
            dayID, plan: viewModel.displayedPlan, isPreview: viewModel.isPreviewingPlan,
            selectedDayID: &selectedDayID, previewDayID: &previewDayID)
        }
      }
      .sheet(isPresented: $showingReadinessSheet, onDismiss: workoutModalDidDismiss) {
        ReadinessCheckinSheet(
          studentID: studentID,
          viewModel: readinessViewModel,
          prefill: readinessPrefill,
          onClose: { showingReadinessSheet = false }
        )
        .presentationDetents([.large])
      }
      .alert(StudentStrings.localized(.todayWorkoutView002), isPresented: actionErrorPresented) {
        Button(StudentStrings.localized(.todayWorkoutView003), role: .cancel) {
          viewModel.clearActionError()
        }
      } message: {
        Text(viewModel.actionErrorMessage ?? "")
      }
      .alert(StudentStrings.trainingShareFailed, isPresented: setRefEntryErrorPresented) {
        Button(StudentStrings.acknowledge, role: .cancel) {
          setRefEntryErrorMessage = nil
        }
      } message: {
        Text(setRefEntryErrorMessage ?? "")
      }
      .sheet(item: $setRefPickerRoute, onDismiss: workoutModalDidDismiss) { route in
        if let chat = notifications?.chatContext, let setRefSharing = chat.setRefSharing {
          SetRefSharePicker(
            context: setRefSharing,
            conversationID: route.conversationID,
            coordinator: chat.sendCoordinator,
            initialSetLogID: route.initialSetID,
            onStaged: {
              setRefPickerRoute = nil
              conversationID = route.conversationID
            }
          )
        }
      }
      .alert(VideoPrivacyCopy.consentTitle, isPresented: $showingDirectCameraConsent) {
        Button(VideoPrivacyCopy.consentAgree) {
          videoViewModel.recordConsent()
          directCameraTarget = pendingDirectCameraTarget
          pendingDirectCameraTarget = nil
        }
        Button(VideoPrivacyCopy.consentDecline, role: .cancel) {
          pendingDirectCameraTarget = nil
        }
      } message: {
        Text(VideoPrivacyCopy.consentBody)
      }
      .confirmationDialog(
        StudentStrings.localized(.todayWorkoutView004),
        isPresented: retryDialogPresented,
        titleVisibility: .visible
      ) {
        Button(StudentStrings.localized(.todayWorkoutView005)) {
          if let setLogID = retryTargetSetLogID {
            Task { await videoViewModel.retry(setLogID: setLogID) }
          }
        }
        Button(StudentStrings.localized(.todayWorkoutView006), role: .destructive) {
          if let setLogID = retryTargetSetLogID {
            Task { await videoViewModel.remove(setLogID: setLogID) }
          }
        }
        Button(StudentStrings.localized(.todayWorkoutView007), role: .cancel) {}
      } message: {
        Text(StudentStrings.localized(.todayWorkoutView008))
      }
      .alert(StudentStrings.localized(.todayWorkoutView009), isPresented: videoRetryErrorPresented)
    {
      Button(StudentStrings.localized(.todayWorkoutView003), role: .cancel) {
        videoViewModel.clearRetryError()
      }
    } message: {
      Text(videoViewModel.retryErrorMessage ?? "")
    }
    #if os(iOS)
      .fullScreenCover(
        item: $directCameraTarget, onDismiss: workoutModalDidDismiss,
        content: directCamera)
    #endif
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        let today = WorkoutDatePolicy.gymDayToday()
        if today != gymDayToday, isVisible, safeHandoffBoundary {
          defaultEntry = true
          selectedDayID = StudentPlanSequence(days: viewModel.planDays).cursorDay?.id
        }
        gymDayToday = today
      }
    }
    .task {
      gymDayToday = WorkoutDatePolicy.gymDayToday()
      let isFirstLoad = viewModel.state == .idle
      if isFirstLoad {
        await loadWorkout(
          for: selectedDayID,
          preloadedPlan: handedOffPlan(for: selectedDayID)
        )
        resolveInitialSelectionIfNeeded()
      }
      await videoViewModel.start(studentID: studentID)
      await videoViewModel.resumePendingAttachments(workout: viewModel, studentID: studentID)
      viewModel.accessoryVideosLoaded = videoViewModel.hasLoadedAttachments
      if uploadFailureNavigationToken > 0 {
        openUploadFailureDestination()
      }
    }
    .onChange(of: viewModel.state) { _, _ in
      Task {
        await videoViewModel.resumePendingAttachments(workout: viewModel, studentID: studentID)
      }
    }
    .onChange(of: videoViewModel.hasLoadedAttachments) { _, loaded in
      viewModel.accessoryVideosLoaded = loaded
    }
    .onChange(of: isVisible) { _, visible in
      if !visible {
        entryReady = false
        resumePrompt = nil
        viewModel.setSyncCompletion?.reset()
      } else {
        Task {
          await enterTrainingIfSafe()
          defaultEntry = true
          entryReady = true
        }
      }
    }
    .onChange(of: viewModel.previewPlan?.cycleID) { _, _ in
      previewDayID = viewModel.previewPlan?.days.first?.id
    }
    .onChange(of: selectedDayID) { _, newDayID in
      guard !viewModel.isPreviewingPlan else { return }
      viewModel.setSyncCompletion?.reset()
      editing = nil
      started = false
      collapsedExercises = [:]
      Task {
        await loadWorkout(
          for: newDayID,
          preloadedPlan: handedOffPlan(for: newDayID)
        )
        if let retryDate = pendingUploadRetryDate,
          retryDate == currentWorkout?.day.scheduledDate
        {
          pendingUploadRetryDate = nil
          await videoViewModel.retryFailures(studentID: studentID, workout: viewModel)
        }
      }
    }
    .onChange(of: planHandoff?.id) { _, _ in
      guard let planHandoff else { return }
      defaultEntry = false
      started = false
      let previousSelection = selectedDayID
      TodayWorkoutSelectionResolver.receive(
        planHandoff, selectedDayID: &selectedDayID, days: viewModel.planDays)
      guard previousSelection == selectedDayID else { return }
      guard let plan = handedOffPlan(for: selectedDayID) else { return }
      Task {
        await loadWorkout(for: selectedDayID, preloadedPlan: plan)
      }
    }
    .onChange(of: jumpToTodayToken) { _, _ in
      // External routes clear only the ephemeral in-process start flag. The
      // presentation still resumes recording when real logs already exist;
      // zero-log days alone return to the explicit pre-start state.
      started = false
      defaultEntry = true
      TodayWorkoutSelectionResolver.receive(
        nil, selectedDayID: &selectedDayID, days: viewModel.planDays)
    }
    .onChange(of: uploadFailureNavigationToken) { _, token in
      guard token > 0 else { return }
      openUploadFailureDestination()
    }
    .onChange(of: planRevision) { _, _ in
      editing = nil
      Task { if safeHandoffBoundary { await loadWorkout(for: selectedDayID) } }
    }
    .onChange(of: planProjectionUpdate) { _, plan in
      guard let plan else { return }
      viewModel.applyPlanProjection(plan)
    }
    .onChange(of: planRefreshRevision) { _, _ in
      gymDayToday = WorkoutDatePolicy.gymDayToday()
      Task { await refreshWorkoutPlan() }
    }
    .onChange(of: viewModel.completionRevision) { _, _ in
      if let waiting = waitingResume,
        viewModel.planDays.first(where: { $0.id == waiting.prompt.id })?.completedAt != nil
      {
        waitingResume = nil
        showCompletedResume(waiting.prompt, date: waiting.date)
      }
      if let plan = viewModel.planProjection {
        onPlanChanged(plan)
      }
    }
    .overlay(alignment: .top) {
      if let quickLogToastWeekCode {
        MeetPRToastCapsule(
          emphasizedText: quickLogToastWeekCode,
          trailingText: StudentStrings.localized(.quickLog027)
        )
        .padding(.top, MeetPRSpacing.space3)
      }
    }
    .onDisappear {
      viewModel.setSyncCompletion?.reset()
      quickLogToastTask?.cancel()
    }
  }

  private func openUploadFailureDestination() {
    guard let destination = uploadFailureDestination,
      handledUploadFailureToken != uploadFailureNavigationToken
    else { return }
    handledUploadFailureToken = uploadFailureNavigationToken
    let targetDayID = viewModel.planDays.first {
      PlanCalendarDayIdentity.matches(
        planDate: $0.scheduledDate,
        selectedDate: destination.trainingDate,
        selectedCalendar: .current
      )
    }?.id
    pendingUploadRetryDate = targetDayID == selectedDayID ? nil : destination.trainingDate
    defaultEntry = false
    selectedDayID = targetDayID
    Task {
      await videoViewModel.retryFailures(studentID: studentID, workout: viewModel)
    }
  }

  @ViewBuilder
  func completionFlow(phase: WorkoutCompletionFlowPhase) -> some View {
    if let workout = currentWorkout {
      let presentation = WorkoutCompletionPresentation(
        day: workout.day,
        drafts: workout.drafts,
        references: viewModel.exerciseReferences,
        weekCode: weekCode,
        coachName: notifications?.activeCoach?.coachDisplayName,
        isSendingToCoach: viewModel.isCompletionSending,
        streak: nil
      )
      WorkoutCompletionFlowView(
        presentation: presentation,
        studentID: studentID,
        initialPhase: phase,
        onFinish: {
          viewModel.completionPhase = nil
          let waitingForVideos =
            viewModel.setSyncQueue?.completionGate.videoWait(dayID: workout.day.id) != nil
          if waitingForVideos {
            retryDayVideos()
          }
          markReviewCompleted(
            for: workout.day.scheduledDate,
            setCount: workout.drafts.count
          )
          Task { await enterTrainingIfSafe() }

        }
      )
    } else {
      Color.MeetPR.bgBase
    }
  }

  private var trainingEmptyState: TrainingEmptyStatePresentation? {
    if viewModel.isPreviewingPlan { return nil }
    guard viewModel.state != .idle, viewModel.state != .loading else { return nil }
    if case .error = viewModel.state { return nil }
    // Pending video/set delivery continues to own the visible day until acknowledged.
    if let day = currentDay,
      viewModel.setSyncQueue?.completionGate.pendingDays.contains(day.id) == true
    {
      return nil
    }
    return TrainingEmptyStatePresentation.resolve(plan: viewModel.planProjection)
  }

  private var screenContent: TodayWorkoutScreen<TrainingWeekStrip>.Content {
    switch viewModel.state {
    case .idle, .loading:
      if let workout = handedOffWorkout(for: selectedDayID) {
        .workout(
          TodayWorkoutPresentation(
            day: workout.day,
            drafts: workout.drafts,
            references: [:],
            videoStates: [:],
            suggestionOutcomes: [:],
            started: started
          )
        )
      } else {
        .loading
      }
    // One pattern, one branch: .loaded → .recording → .loaded round-trips
    // during every persist. Keeping one structural identity prevents SwiftUI
    // from dismissing and re-presenting SetEntrySheet with reset fields.
    case .loaded(let day, let drafts), .recording(let day, let drafts, _):
      .workout(
        TodayWorkoutPresentation(
          day: day,
          drafts: drafts,
          references: viewModel.exerciseReferences,
          videoStates: videoStates(for: drafts),
          suggestionOutcomes: suggestionOutcomes(for: drafts),
          started: started
        )
      )
    case .noPlan:
      .noPlan
    case .error(let message):
      .error(message)
    }
  }

  private func suggestionOutcomes(
    for drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> [UUID: SetWeightSuggestionOutcome] {
    Dictionary(
      uniqueKeysWithValues: drafts.map {
        ($0.id, viewModel.weightSuggestionOutcome(forSetID: $0.id))
      }
    )
  }

  private var currentWorkout: (day: StudentPlanDay, drafts: [TodayWorkoutViewModel.SetRowDraft])? {
    switch viewModel.state {
    case .loaded(let day, let drafts), .recording(let day, let drafts, _):
      (day, drafts)
    case .idle, .loading:
      handedOffWorkout(for: selectedDayID)
    case .noPlan, .error:
      nil
    }
  }

  private var currentDay: StudentPlanDay? {
    currentWorkout?.day
  }

  private var isEditable: Bool {
    guard !viewModel.browsingPastPlan, !viewModel.isPreviewingPlan, let currentDay else {
      return false
    }
    return FlexibleTrainingDay.canWrite(currentDay, in: viewModel.planDays)
  }

  private var selectedDayState: TodayWorkoutDayState {
    guard let currentDay else { return .current }
    if currentDay.completedAt != nil { return .completed(canUndo: canUndoCurrentDay) }
    return isEditable
      ? .current : .upcoming(previousDay: StudentPlanSequence(days: viewModel.planDays).cursorDay)
  }

  private var canUndoCurrentDay: Bool {
    guard let currentDay else { return false }
    return FlexibleTrainingDay.canUndo(currentDay.id, days: viewModel.planDays, now: Date())
  }

  private var sequencePage: TrainingSequencePage {
    TrainingSequenceLayout.page(days: viewModel.planDays, selectedDayID: selectedDayID)
  }

  private func returnToCurrentDay() {
    if viewModel.browsingPastPlan || viewModel.isPreviewingPlan {
      Task {
        await viewModel.returnToCurrentPlan(isSafe: { safeHandoffBoundary })
        selectedDayID = viewModel.currentDay?.id
      }
    } else {
      selectedDayID = sequencePage.currentSelection
    }
  }

  private func reloadCurrentDay() async {
    await replay.load(studentID: studentID)
    await loadWorkout(for: nil)
  }

  private var selectedTrainingDate: Date {
    currentDay?.scheduledDate ?? initialDate ?? Date()
  }

  private var weekCode: String {
    if let previewDay { return "W\(previewDay.weekNumber)" }
    if viewModel.handoff != nil, let currentDay { return "W\(currentDay.weekNumber)" }
    if viewModel.state == .noPlan {
      return "W—"
    }
    let title = TodayWorkoutTitleResolver.title(
      day: currentDay,
      days: viewModel.planDays,
      planContext: viewModel.planContext,
      onboarding: viewModel.onboardingProfile
    )
    return title.split(separator: "·").first.map {
      String($0).trimmingCharacters(in: .whitespaces)
    } ?? StudentStrings.localized(.todayWorkoutView010)
  }

  private func openEditor(_ row: TodayWorkoutPresentation.Row) {
    guard isEditable else { return }
    editing = EditingTarget(
      id: row.id,
      rowIndex: row.stableIndex,
      draft: row.draft,
      setNumber: row.record.index,
      scrollToVideo: false
    )
  }

  private func openQuickLog() {
    guard isEditable, let currentDay, let plan = viewModel.makeQuickLogPlan() else {
      return
    }
    quickLogRoute = QuickLogRoute(
      day: currentDay,
      weekCode: TrainingSequenceText.code(for: currentDay, in: viewModel.planDays),
      plan: plan
    )
  }

  private func quickLogSheet(for route: QuickLogRoute) -> some View {
    QuickLogSheet(
      day: route.day,
      weekCode: route.weekCode,
      plan: route.plan,
      viewModel: viewModel,
      onSuccess: {
        finishQuickLog(weekCode: route.weekCode)
      }
    )
  }

  private func finishQuickLog(weekCode: String) {
    quickLogRoute = nil
    selectedDayID = StudentPlanSequence(days: viewModel.planDays).cursorDay?.id
    quickLogToastTask?.cancel()
    quickLogToastWeekCode = weekCode
    quickLogToastTask = Task {
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      quickLogToastWeekCode = nil
    }
  }

  private func completeTraining() {
    Task {
      if await viewModel.completeCurrentDay(), viewModel.completionPhase == nil {
        // The student may have closed the reward while it was sending.
        returnToCurrentDay()

      }
    }
  }

  private func setEntry(for target: EditingTarget) -> some View {
    AllDayVideoSheet(
      draft: target.draft, viewModel: viewModel, studentID: studentID,
      trainingDate: selectedTrainingDate, videoViewModel: videoViewModel)

  }

  private func openVideoAction(_ row: TodayWorkoutPresentation.Row) {
    guard isEditable else { return }
    switch SetVideoButtonDestination.resolve(
      for: videoIndicatorStatus(for: row.draft),
      cameraAvailable: true
    ) {
    case .camera:
      beginDirectCamera(for: row.draft)
    case .details:
      editing = EditingTarget(
        id: row.id,
        rowIndex: row.stableIndex,
        draft: row.draft,
        setNumber: row.record.index,
        scrollToVideo: true
      )
    case .retry:
      if videoRowState(for: row.draft)?.attachment.pendingDraftID != nil {
        editing = EditingTarget(
          id: row.id, rowIndex: row.stableIndex, draft: row.draft,
          setNumber: row.record.index, scrollToVideo: true)
      } else {
        retryTargetSetLogID = row.draft.loggedSetID
      }
    }
  }

  private var videoCompletionRevision: Int {
    viewModel.setSyncQueue?.videoCompletion?.revision ?? 0
  }

  private var videoCompletionPresentation: VideoCompletionPresentation? {
    guard case .workout(let presentation) = screenContent,
      presentation.day.completedAt == nil
    else { return nil }
    return VideoCompletionPresentation(
      attachments: videoViewModel.rowStates.values.map(\.attachment),
      trainingDate: presentation.day.scheduledDate,
      allSetsDone: presentation.trainingFlow(isEditable: true)?.progress.allDone
        ?? presentation.progress.allDone,
      waiting: viewModel.setSyncQueue?.completionGate.videoWait(dayID: presentation.day.id) != nil)
  }

  private var videoFailurePresentation: VideoDeliveryPresentation {
    VideoDeliveryPresentation(
      drafts: viewModel.currentDrafts ?? [], trainingDate: selectedTrainingDate,
      attachments: videoViewModel.rowStates.values.map(\.attachment))
  }

  private func retryDayVideos() {
    let date = selectedTrainingDate
    Task {
      await videoViewModel.retryFailures(
        studentID: studentID, workout: viewModel, trainingDate: date)
    }
  }

  private func missingVideoContext(_ attachment: VideoAttachment) -> String {
    guard
      let draft = viewModel.currentDrafts?.first(where: {
        VideoDeliveryPresentation.attachment(
          for: $0, trainingDate: selectedTrainingDate, in: [attachment]) != nil
      })
    else { return attachment.trainingDate.formatted(date: .abbreviated, time: .omitted) }
    let row = CompletedDayPresentation.Row(
      draft: draft, unit: viewModel.onboardingProfile?.unitPreference ?? .kg,
      videos: [], local: [], trainingDate: selectedTrainingDate)
    let setLabel = HistoryEntriesView.setLabel(forZeroBasedIndex: row.number - 1)
    return "\(draft.displayExerciseName) · \(setLabel) · \(row.result)"
  }

  private func videoStates(
    for drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> [UUID: SetRow.VideoState] {
    Dictionary(
      uniqueKeysWithValues: drafts.compactMap { draft in
        return (draft.loggedSetID ?? draft.id, setRowVideoState(for: draft))
      }
    )
  }

  private func setRowVideoState(
    for draft: TodayWorkoutViewModel.SetRowDraft
  ) -> SetRow.VideoState {
    switch videoIndicatorStatus(for: draft) {
    case .pending, .uploading:
      .uploading
    case .uploaded:
      .uploaded
    case .failed:
      .failed
    case .none:
      .none
    }
  }

  private func videoRowState(
    for draft: TodayWorkoutViewModel.SetRowDraft
  ) -> VideoAttachmentViewModel.RowState? {
    videoViewModel.pendingRowState(
      draftID: draft.id, trainingDate: selectedTrainingDate, slot: draft.pendingVideoSlot)
      ?? draft.loggedSetID.flatMap { videoViewModel.rowStates[$0] }
  }

  private func videoIndicatorStatus(
    for draft: TodayWorkoutViewModel.SetRowDraft
  ) -> VideoAttachment.Status? {
    if preparingVideoSetID == draft.id { return .pending }
    guard let attachment = videoRowState(for: draft)?.attachment else { return nil }
    return VideoDeliveryPresentation.hasFailure(attachment) ? .failed : attachment.status
  }

  #if os(iOS)
    private func directCamera(for target: DirectCameraTarget) -> CameraRecorderView {
      CameraRecorderView(
        maxDurationSeconds: videoViewModel.maxDurationSeconds,
        isPresented: Binding(
          get: { directCameraTarget != nil },
          set: { if !$0 { directCameraTarget = nil } }),
        onPicked: { url in
          preparingVideoSetID = target.id
          Task {
            await attachDirectCameraVideo(sourceURL: url, target: target)
          }
        },
        onFailure: { error in
          videoViewModel.reportVideoProcessingFailure(draftID: target.id, error: error)
        },
        allDayFlow: true
      )
    }
  #endif

  private var cameraAvailable: Bool {
    #if os(iOS)
      CameraRecorderView.isAvailable
    #else
      false
    #endif
  }

  private func beginDirectCamera(for draft: TodayWorkoutViewModel.SetRowDraft) {
    let target = DirectCameraTarget(
      id: draft.id, trainingDate: selectedTrainingDate, slot: draft.pendingVideoSlot)
    if videoViewModel.hasConsented {
      directCameraTarget = target
    } else {
      pendingDirectCameraTarget = target
      showingDirectCameraConsent = true
    }
  }

  private func attachDirectCameraVideo(
    sourceURL: URL,
    target: DirectCameraTarget
  ) async {
    await videoViewModel.attach(
      sourceURL: sourceURL, draftID: target.id, studentID: studentID,
      trainingDate: target.trainingDate, slot: target.slot,
      resolveSetLogID: {
        await viewModel.resolveVideoSetLogID(draftID: target.id, trainingDate: target.trainingDate)
      })
    preparingVideoSetID = nil
  }

  private func markReviewCompleted(for date: Date, setCount: Int) {
    reviewStore.markReviewCompleted(studentId: studentID, date: date)
    reviewCompleted = true
    guard let startedAt = workoutStartedAt.wrappedValue else { return }
    Analytics.shared.workoutLogSaved(
      setCount: setCount,
      durationMilliseconds: max(
        0,
        Int(Date().timeIntervalSince(startedAt) * 1_000)
      )
    )
    workoutStartedAt.wrappedValue = nil
  }

  private var actionErrorPresented: Binding<Bool> {
    Binding(
      get: { viewModel.actionErrorMessage != nil },
      set: { if !$0 { viewModel.clearActionError() } }
    )
  }

  private var setRefEntryErrorPresented: Binding<Bool> {
    Binding(
      get: { setRefEntryErrorMessage != nil },
      set: { if !$0 { setRefEntryErrorMessage = nil } }
    )
  }

  private var retryDialogPresented: Binding<Bool> {
    Binding(
      get: { retryTargetSetLogID != nil },
      set: { if !$0 { retryTargetSetLogID = nil } }
    )
  }

  private var videoRetryErrorPresented: Binding<Bool> {
    Binding(
      get: { videoViewModel.retryErrorMessage != nil },
      set: { if !$0 { videoViewModel.clearRetryError() } }
    )
  }

  private var readinessPrefill: ReadinessCheckin? {
    if case .done(let checkin) = readinessViewModel.gate { return checkin }
    return nil
  }

  private var showsSetRefEntry: Bool {
    guard let currentWorkout else { return false }
    return SetRefEntryVisibility.shouldShow(
      drafts: currentWorkout.drafts,
      isEditable: isEditable,
      hasActiveCoach: notifications?.activeCoach != nil,
      hasSharingContext: notifications?.chatContext?.setRefSharing != nil
    )
  }

  private func openExerciseNote(_ draft: TodayWorkoutSetRowDraft) {
    guard let day = currentDay else { return }
    exerciseNote = ExerciseRefV1(
      exerciseName: draft.displayExerciseName,
      dayDate: day.date.formatted(.iso8601.year().month().day().dateSeparator(.dash)),
      planDayID: day.id,
      planExerciseID: !draft.isStudentAdded ? draft.planExerciseID : nil,
      exerciseID: draft.exerciseID)
  }

  private func openSetRefPicker() {
    guard !isPreparingSetRefPicker, let notifications else { return }
    isPreparingSetRefPicker = true
    setRefEntryErrorMessage = nil
    Task {
      let result = await notifications.openCoachConversation()
      isPreparingSetRefPicker = false
      guard case .opened(let openedConversationID) = result else {
        setRefEntryErrorMessage = StudentStrings.trainingShareConversationFailed
        return
      }
      let drafts = currentWorkout?.drafts ?? []
      let current = drafts.first { !$0.completed } ?? drafts.last
      setRefPickerRoute = SetRefPickerRoute(
        conversationID: openedConversationID,
        initialSetID: current.flatMap { $0.loggedSetID ?? $0.prescribed.id })
    }
  }

  private var previewDay: StudentPlanDay? {
    viewModel.previewPlan?.days.first { $0.id == previewDayID } ?? viewModel.previewPlan?.days.first
  }

  private var displayedDayBinding: Binding<UUID?> {
    Binding(
      get: { viewModel.isPreviewingPlan ? previewDay?.id : selectedDayID },
      set: {
        defaultEntry = false
        if viewModel.isPreviewingPlan { previewDayID = $0 } else { selectedDayID = $0 }
      })
  }

  private var safeHandoffBoundary: Bool {
    resumePrompt == nil && !showingCycleOutlook && editing == nil && quickLogRoute == nil
      && directCameraTarget == nil
      && pendingDirectCameraTarget == nil && preparingVideoSetID == nil
      && weightEntry?.isPresented != true
      && viewModel.completionPhase == nil && keypad?.current == nil
      && !videoViewModel.rowStates.values.contains { $0.attachment.status == .uploading }
  }

  private func workoutModalDidDismiss() { workoutModalIsPresented = false }

  private var hasRequestedWorkoutModal: Bool {
    resumePrompt != nil || editing != nil || quickLogRoute != nil
      || viewModel.completionPhase != nil
      || showingCycleOutlook || showingReadinessSheet || setRefPickerRoute != nil
      || directCameraTarget != nil
      || exerciseNote != nil || replay.selected != nil || videoViewModel.missingAttachment != nil
  }

  private var restRingPresentationBlocked: Bool {
    if ancestorPresentationBlocked || bindFirstRun?.showsWelcome == true
      || (viewModel.showsHandoffNotice && !viewModel.browsingPastPlan)
    {
      return true
    }
    if hasRequestedWorkoutModal || workoutModalIsPresented || childPresentationBlocked
      || showingHistory || weightEntry?.isPresented == true
    {
      return true
    }
    if showingDirectCameraConsent || pendingDirectCameraTarget != nil
      || preparingVideoSetID != nil || exerciseNavigation?.reference != nil
    {
      return true
    }
    return isPreparingSetRefPicker || setRefEntryErrorMessage != nil || retryTargetSetLogID != nil
      || viewModel.actionErrorMessage != nil || videoViewModel.retryErrorMessage != nil
  }

  private func turnPlan(forward: Bool) {
    guard safeHandoffBoundary else { return }
    Task {
      await viewModel.browseAdjacentPlan(forward: forward, isSafe: { safeHandoffBoundary })
      if viewModel.isPreviewingPlan {
        previewDayID = viewModel.previewPlan?.days.first?.id
      } else {
        selectedDayID = viewModel.currentDay?.id
      }
    }
  }

  private struct VisitContext: Equatable {
    let plan: UUID
    let day: UUID
    let today: Date
    let canPrompt: Bool
  }

  private var visitContext: VisitContext? {
    guard isVisible, entryReady, scenePhase == .active, !showingHistory,
      !ancestorPresentationBlocked, !childPresentationBlocked, bindFirstRun?.showsWelcome != true,
      !hasRequestedWorkoutModal, !viewModel.isCompletionMutationInFlight,
      !viewModel.isPreviewingPlan,
      !viewModel.browsingPastPlan, let plan = viewModel.planProjection,
      plan.actualCompletionDateEnabled, case .loaded(let day, _) = viewModel.state,
      day.id == selectedDayID, day.completedAt == nil,
      viewModel.setSyncQueue?.completionGate.videoWait(dayID: day.id) == nil
    else { return nil }
    let cursor = StudentPlanSequence(days: plan.days).cursorDay?.id
    return VisitContext(
      plan: plan.cycleID, day: day.id, today: gymDayToday,
      canPrompt: defaultEntry && cursor == day.id)
  }

  private func checkResume(_ context: VisitContext?) {
    // A hidden tab or interrupted loading state cannot establish a visit.
    guard let context else { return }
    guard resumePrompt == nil, let day = viewModel.currentDay else { return }
    guard
      let last = resumeVisits.open(
        student: studentID, plan: context.plan,
        day: context.day, today: context.today, prompt: context.canPrompt)
    else { return }
    let rows = (viewModel.currentDrafts ?? []).filter { !$0.isWarmup && !$0.isBlankAddedRow }
    resumePrompt = WorkoutResumePrompt(
      id: day.id, planID: context.plan,
      code: TrainingSequenceText.code(for: day, in: viewModel.planDays),
      lastOpened: last, today: context.today, recorded: rows.filter(\.hasSavedRecord).count,
      total: rows.count)
  }

  private func finishResume(_ prompt: WorkoutResumePrompt, date: Date) async -> Bool {
    guard isVisible, prompt.planID == viewModel.planProjection?.cycleID,
      (prompt.lastOpened...prompt.today).contains(date)
        || viewModel.lockedResumeDate(dayID: prompt.id) == date,
      await viewModel.completeResumedDay(id: prompt.id, actualDate: date)
    else { return false }
    resumeVisits.continueDay(
      student: studentID, plan: prompt.planID, day: prompt.id, today: gymDayToday)
    resumePrompt = nil
    if viewModel.planDays.first(where: { $0.id == prompt.id })?.completedAt != nil {
      showCompletedResume(prompt, date: date)
    } else {
      waitingResume = (prompt, date)
      showResumeNotice(StudentStrings.localized(.resumeWaiting))
    }
    return true
  }

  private func showCompletedResume(_ prompt: WorkoutResumePrompt, date: Date) {
    let next = StudentPlanSequence(days: viewModel.planDays).cursorDay
    let actual = viewModel.planDays.first { $0.id == prompt.id }?.actualCompletionDate
    let selected = TodayWorkoutViewModel.gymDate(
      WorkoutDatePolicy.deviceCalendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
        ?? date,
      calendar: WorkoutDatePolicy.deviceCalendar)
    let completed = [prompt.code, StudentFormatting.monthDay(date)]
    if actual != selected {
      selectedDayID = next?.id ?? prompt.id
      defaultEntry = false
      showResumeNotice(StudentStrings.replacing(.resumeAlreadyFinished, values: [prompt.code]))
      return
    }
    defaultEntry = false
    if let next {
      selectedDayID = next.id
      let code = TrainingSequenceText.code(for: next, in: viewModel.planDays)
      showResumeNotice(StudentStrings.replacing(.resumeAdvanced, values: completed + [code]))
    } else {
      showResumeNotice(StudentStrings.replacing(.resumeFinished, values: completed))
    }
  }

  private func showResumeNotice(_ message: String) {
    resumeNoticeTask?.cancel()
    resumeNotice = message
    resumeNoticeTask = Task {
      do { try await Task.sleep(for: .seconds(5)) } catch { return }
      withAnimation(.easeOut(duration: 0.2)) { resumeNotice = nil }
    }
  }

  private func enterTrainingIfSafe() async {
    guard safeHandoffBoundary else { return }
    await viewModel.enterTraining(isSafe: { safeHandoffBoundary })
    selectedDayID = viewModel.currentDay?.id
  }

  private func loadWorkout(
    for dayID: UUID?,
    preloadedPlan: StudentPlanView? = nil
  ) async {
    if viewModel.isPreviewingPlan { return }
    if viewModel.browsingPastPlan {
      await viewModel.loadBrowsingDay(dayID)
      return
    }
    let plan: StudentPlanView?
    if dayID == nil, preloadedPlan == nil {
      plan = try? await plans.fetchCurrentPlan(studentID: studentID)
    } else {
      plan = preloadedPlan
    }
    let target =
      dayID
      ?? plan.flatMap {
        StudentTabShellPresentation.initialTrainingDay(in: $0.days)
      }
    await viewModel.load(dayID: target, studentID: studentID, preloadedPlan: plan)
    if selectedDayID == nil || !viewModel.planDays.contains(where: { $0.id == selectedDayID }) {
      selectedDayID = currentDay?.id
    }
    if let currentDay, currentDay.id == selectedDayID {
      reviewCompleted = reviewStore.didCompleteReview(
        studentId: studentID,
        date: currentDay.scheduledDate
      )
    }
    await refreshReadinessStatus()
    guard let coachRPEReconciler,
      let reconciliation = await viewModel.reconcileCoachRPE(
        using: coachRPEReconciler,
        studentID: studentID
      ),
      reconciliation.didReconcile,
      currentDay?.id == selectedDayID
    else { return }
    await viewModel.load(dayID: selectedDayID ?? target, studentID: studentID)
  }

  private func refreshWorkoutPlan() async {
    guard safeHandoffBoundary else { return }
    await viewModel.refreshCurrentPlanIfAllowed(
      dayID: selectedDayID,
      studentID: studentID,
      at: Date()
    )
    if selectedDayID == nil || !viewModel.planDays.contains(where: { $0.id == selectedDayID }) {
      selectedDayID = currentDay?.id
    }
  }

  private func handedOffPlan(for dayID: UUID?) -> StudentPlanView? {
    guard let planHandoff, planHandoff.dayID == dayID
    else {
      return nil
    }
    return planHandoff.plan
  }

  private func handedOffWorkout(
    for dayID: UUID?
  ) -> (day: StudentPlanDay, drafts: [TodayWorkoutViewModel.SetRowDraft])? {
    guard let dayID, let plan = handedOffPlan(for: dayID),
      let day = plan.days.first(where: { $0.id == dayID })
    else {
      return nil
    }
    return (
      day,
      TodayWorkoutViewModel.makeDrafts(
        for: day,
        existingLogs: planHandoff?.existingLogs ?? []
      )
    )
  }

  private func refreshReadinessStatus() async {
    guard isEditable else { return }
    await readinessViewModel.load(studentId: studentID)
  }

  private func resolveInitialSelectionIfNeeded() {
    guard let initialDate, planHandoff == nil else { return }
    selectedDayID =
      viewModel.planDays.first {
        PlanCalendarDayIdentity.matches(
          planDate: $0.scheduledDate,
          selectedDate: initialDate,
          selectedCalendar: .current
        )
      }?.id ?? selectedDayID
  }
}

enum TodayWorkoutTitleResolver {
  static func title(
    day: StudentPlanDay?,
    days: [StudentPlanDay],
    planContext: TodayWorkoutPlanContext?,
    onboarding: OnboardingProfile?
  ) -> String {
    guard let day else { return StudentStrings.localized(.todayWorkoutView011) }
    let weekday = TrainingSequenceText.code(for: day, in: days)
    let family = day.exercises.lazy.compactMap {
      resolveCompetitionFamily(exercise: $0.exercise, onboarding: onboarding)
    }.first
    guard let lift = family?.studentDisplayName else { return weekday }
    return "\(weekday) · \(lift)"
  }

}

@available(iOS 17.0, macOS 14.0, *)
private struct EditingTarget: Identifiable {
  let id: UUID
  let rowIndex: Int
  let draft: TodayWorkoutViewModel.SetRowDraft
  let setNumber: Int
  let scrollToVideo: Bool
}

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogRoute: Identifiable {
  let id = UUID()
  let day: StudentPlanDay
  let weekCode: String
  let plan: QuickLogPlan
}

private struct DirectCameraTarget: Identifiable {
  let id: UUID
  let trainingDate: Date
  let slot: VideoAttachment.SetSlot?
}

private struct SetRefPickerRoute: Identifiable {
  var id: UUID { conversationID }

  let conversationID: UUID
  let initialSetID: UUID?
}

enum SetRefEntryVisibility {
  static func shouldShow(
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    isEditable: Bool,
    hasActiveCoach: Bool,
    hasSharingContext: Bool
  ) -> Bool {
    shouldShow(
      isEditable: isEditable,
      hasAvailableSet: drafts.contains {
        !$0.isExtra && !$0.isStudentAdded && $0.needsTrainingResult
      },
      hasActiveCoach: hasActiveCoach,
      hasSharingContext: hasSharingContext
    )
  }

  static func shouldShow(
    isEditable: Bool,
    hasAvailableSet: Bool,
    hasActiveCoach: Bool,
    hasSharingContext: Bool
  ) -> Bool {
    isEditable && hasAvailableSet && hasActiveCoach && hasSharingContext
  }
}
// swiftlint:enable file_length type_body_length
