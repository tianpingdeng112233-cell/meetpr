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
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let coachRPEReconciler: E1RMCoachRPEReconciler?
  private let planHandoff: TodayWorkoutPlanHandoff?
  private let initialDate: Date?
  private let jumpToTodayToken: Int
  private let uploadFailureDestination: UploadFailureDestination?
  private let uploadFailureNavigationToken: Int
  private let autoStartToken: Int
  private let isLaunchTargetHidden: Bool
  private let launchHeroRevealToken: Int
  private let planRevision: Int
  private let planProjectionUpdate: StudentPlanView?
  private var workoutStartedAt: Binding<Date?>
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onPlanChanged: (StudentPlanView) -> Void
  private let onHeroFrameChange: (CGRect) -> Void
  private let onReturnToToday: () -> Void

  @State private var viewModel: TodayWorkoutViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var videoViewModel: VideoAttachmentViewModel
  @State private var selectedDayID: UUID?
  @State private var completionPhase: WorkoutCompletionFlowPhase?
  @State private var editing: EditingTarget?
  @State private var directCameraTarget: DirectCameraTarget?
  @State private var showingDirectCameraConsent = false
  @State private var showingDirectCamera = false
  @State private var preparingVideoSetID: UUID?
  @State private var retryTargetSetLogID: UUID?
  @State private var showingReadinessSheet = false
  @State private var showingNotifications = false
  @State private var conversationID: UUID?
  @State private var setRefPickerRoute: SetRefPickerRoute?
  @State private var isPreparingSetRefPicker = false
  @State private var setRefEntryErrorMessage: String?
  @State private var reviewCompleted = false
  @State private var started = false
  @State private var autoStartGate = TodayWorkoutAutoStartGate()
  @State private var collapsedExercises: [UUID: Bool] = [:]
  @Namespace private var heroNamespace

  private let reviewStore: any SessionReviewStore = UserDefaultsSessionReviewStore()

  public init(
    studentID: UUID,
    date: Date? = nil,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    onboarding: (any OnboardingProfileReading)? = nil,
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    videoUploads: VideoUploadServices? = nil,
    planHandoff: TodayWorkoutPlanHandoff? = nil,
    jumpToTodayToken: Int = 0,
    uploadFailureDestination: UploadFailureDestination? = nil,
    uploadFailureNavigationToken: Int = 0,
    autoStartToken: Int = 0,
    isLaunchTargetHidden: Bool = false,
    launchHeroRevealToken: Int = 0,
    planRevision: Int = 0,
    planProjectionUpdate: StudentPlanView? = nil,
    workoutStartedAt: Binding<Date?> = .constant(nil),
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {},
    onPlanChanged: @escaping (StudentPlanView) -> Void = { _ in },
    onHeroFrameChange: @escaping (CGRect) -> Void = { _ in },
    onReturnToToday: @escaping () -> Void = {}
  ) {
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
    self.planHandoff = planHandoff
    self.initialDate = date
    self.jumpToTodayToken = jumpToTodayToken
    self.uploadFailureDestination = uploadFailureDestination
    self.uploadFailureNavigationToken = uploadFailureNavigationToken
    self.autoStartToken = autoStartToken
    self.isLaunchTargetHidden = isLaunchTargetHidden
    self.launchHeroRevealToken = launchHeroRevealToken
    self.planRevision = planRevision
    self.planProjectionUpdate = planProjectionUpdate
    self.workoutStartedAt = workoutStartedAt
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onPlanChanged = onPlanChanged
    self.onHeroFrameChange = onHeroFrameChange
    self.onReturnToToday = onReturnToToday
    self._selectedDayID = State(initialValue: planHandoff?.dayID)
    self._viewModel = State(
      initialValue: TodayWorkoutViewModel(
        plans: plans,
        logs: logs,
        e1rm: e1rm,
        onboarding: onboarding,
        restTimerSettings: restTimerSettings
      )
    )
    self._readinessViewModel = State(
      initialValue: ReadinessCheckinViewModel(repo: readiness)
    )
    self._videoViewModel = State(
      initialValue: VideoAttachmentViewModel(manager: (videoUploads ?? .demo()).manager)
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
    NavigationStack {
      TodayWorkoutScreen(
        content: screenContent,
        weekCode: weekCode,
        dayState: selectedDayState,
        reviewCompleted: reviewCompleted,
        unreadCount: notifications?.totalUnreadCount ?? 0,
        showsNotifications: notifications != nil,
        coachName: notifications?.activeCoach?.coachDisplayName ?? "教练",
        showsAskCoach: showsSetRefEntry,
        isPreparingAskCoach: isPreparingSetRefPicker,
        namespace: heroNamespace,
        isLaunchTargetHidden: isLaunchTargetHidden,
        launchHeroRevealToken: launchHeroRevealToken,
        collapsedExercises: $collapsedExercises,
        calendarContent: TrainingCalendarView(
          selectedDayID: $selectedDayID,
          days: viewModel.planDays
        ),
        onRefresh: {
          Task { await loadWorkout(for: selectedDayID) }
        },
        onReadiness: {
          showingReadinessSheet = true
        },
        onNotifications: {
          showingNotifications = true
        },
        onMessageCoach: {
          showingNotifications = true
        },
        onAskCoach: openSetRefPicker,
        onHeroFrameChange: onHeroFrameChange,
        onStart: {
          started = true
        },
        onEdit: openEditor,
        onVideoAction: openVideoAction,
        onComplete: {
          Task {
            if await viewModel.completeCurrentDay() {
              completionPhase = .celebration
            }
          }
        },
        onUndoCompletion: {
          Task {
            _ = await viewModel.undoCurrentDayCompletion()
          }
        },
        onShowReview: {
          completionPhase = .review
        }
      )
      #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
      #endif
      .modifier(
        OptionalStudentNotificationHostModifier(
          coordinator: notifications,
          showsNotifications: $showingNotifications,
          conversationID: $conversationID,
          onOpenPlan: onOpenPlanNotification
        )
      )
    }
    .safeAreaInset(edge: .bottom) {
      if let timer = viewModel.restTimer {
        RestTimerOverlay(
          timer: timer,
          now: { Date() },
          onAdjust: { viewModel.adjustRestTimer(bySeconds: $0) },
          onSkip: { viewModel.skipRestTimer() }
        )
      }
    }
    .animation(MeetPRMotion.spring, value: viewModel.restTimer)
    #if os(iOS)
      .fullScreenCover(item: $editing) { target in
        setEntry(for: target)
      }
    #else
      .sheet(item: $editing) { target in
        setEntry(for: target)
      }
    #endif
    #if os(iOS)
      .fullScreenCover(item: $completionPhase) { phase in
        completionFlow(phase: phase)
      }
    #else
      .sheet(item: $completionPhase) { phase in
        completionFlow(phase: phase)
      }
    #endif
    .sheet(isPresented: restTimerExplanationPresented) {
      RestTimerExplanationView {
        viewModel.acknowledgeRestTimerExplanation()
      }
      .presentationDetents([.medium])
      .interactiveDismissDisabled()
    }
    .sheet(isPresented: $showingReadinessSheet) {
      ReadinessCheckinSheet(
        studentID: studentID,
        viewModel: readinessViewModel,
        prefill: readinessPrefill,
        onClose: { showingReadinessSheet = false }
      )
      .presentationDetents([.large])
    }
    .alert("保存失败", isPresented: actionErrorPresented) {
      Button("知道了", role: .cancel) { viewModel.clearActionError() }
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
    .sheet(item: $setRefPickerRoute) { route in
      if let chat = notifications?.chatContext, let setRefSharing = chat.setRefSharing {
        SetRefSharePicker(
          context: setRefSharing,
          conversationID: route.conversationID,
          coordinator: chat.sendCoordinator,
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
        showingDirectCamera = directCameraTarget != nil
      }
      Button(VideoPrivacyCopy.consentDecline, role: .cancel) {
        directCameraTarget = nil
      }
    } message: {
      Text(VideoPrivacyCopy.consentBody)
    }
    .confirmationDialog(
      "视频上传失败",
      isPresented: retryDialogPresented,
      titleVisibility: .visible
    ) {
      Button("重试上传") {
        if let setLogID = retryTargetSetLogID {
          Task { await videoViewModel.retry(setLogID: setLogID) }
        }
      }
      Button("删除视频", role: .destructive) {
        if let setLogID = retryTargetSetLogID {
          Task { await videoViewModel.remove(setLogID: setLogID) }
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("视频仍保存在本机,可直接重试上传。")
    }
    #if os(iOS)
      .fullScreenCover(
        isPresented: $showingDirectCamera,
        onDismiss: { directCameraTarget = nil },
        content: {
          CameraRecorderView(
            maxDurationSeconds: videoViewModel.maxDurationSeconds,
            isPresented: $showingDirectCamera,
            onPicked: { url in
              guard let target = directCameraTarget else {
                try? FileManager.default.removeItem(at: url)
                videoViewModel.reportVideoProcessingFailure()
                return
              }
              preparingVideoSetID = target.id
              Task {
                await attachDirectCameraVideo(sourceURL: url, target: target)
              }
            },
            onFailure: {
              videoViewModel.reportVideoProcessingFailure()
            }
          )
          .ignoresSafeArea()
        }
      )
    #endif
    .task {
      let isFirstLoad = viewModel.state == .idle
      if isFirstLoad {
        await loadWorkout(
          for: selectedDayID,
          preloadedPlan: handedOffPlan(for: selectedDayID)
        )
        resolveInitialSelectionIfNeeded()
      }
      // A CTA tap can mount this view with the token already advanced, in
      // which case onChange(of: autoStartToken) never fires — hand the gate
      // the current token before consuming, or a cold-start CTA launch
      // strands the morph waiting for a recording hero that never comes.
      if autoStartToken > 0 {
        autoStartGate.receive(token: autoStartToken)
      }
      consumePendingAutoStartIfReady()
      await videoViewModel.start(studentID: studentID)
      if uploadFailureNavigationToken > 0 {
        openUploadFailureDestination()
      }
    }
    .onChange(of: selectedDayID) { _, newDayID in
      editing = nil
      started = false
      collapsedExercises = [:]
      Task {
        await loadWorkout(
          for: newDayID,
          preloadedPlan: handedOffPlan(for: newDayID)
        )
        consumePendingAutoStartIfReady()
      }
    }
    .onChange(of: planHandoff?.id) { _, _ in
      guard let plan = handedOffPlan(for: selectedDayID) else { return }
      Task {
        await loadWorkout(for: selectedDayID, preloadedPlan: plan)
        consumePendingAutoStartIfReady()
      }
    }
    .onChange(of: jumpToTodayToken) { _, _ in
      if let jumpTarget = TodayWorkoutSelectionResolver.jumpToCurrentSelection(
        from: selectedDayID,
        days: viewModel.planDays
      ) {
        selectedDayID = jumpTarget
      }
    }
    .onChange(of: uploadFailureNavigationToken) { _, token in
      guard token > 0 else { return }
      openUploadFailureDestination()
    }
    .onChange(of: autoStartToken) { _, token in
      guard token > 0 else { return }
      autoStartGate.receive(token: token)
      consumePendingAutoStartIfReady()
    }
    .onChange(of: planRevision) { _, _ in
      editing = nil
      Task { await loadWorkout(for: selectedDayID) }
    }
    .onChange(of: planProjectionUpdate) { _, plan in
      guard let plan else { return }
      viewModel.applyPlanProjection(plan)
    }
    .onChange(of: viewModel.completionRevision) { _, _ in
      if let plan = viewModel.planProjection {
        onPlanChanged(plan)
      }
    }
  }

  private func openUploadFailureDestination() {
    guard let destination = uploadFailureDestination else { return }
    selectedDayID =
      viewModel.planDays.first {
        PlanCalendarDayIdentity.matches(
          planDate: $0.scheduledDate,
          selectedDate: destination.trainingDate,
          selectedCalendar: .current
        )
      }?.id
    retryTargetSetLogID = destination.setLogID
  }

  @ViewBuilder
  private func completionFlow(phase: WorkoutCompletionFlowPhase) -> some View {
    if let workout = currentWorkout {
      let presentation = WorkoutCompletionPresentation(
        day: workout.day,
        drafts: workout.drafts,
        references: viewModel.exerciseReferences,
        weekCode: weekCode,
        coachName: notifications?.activeCoach?.coachDisplayName,
        streak: nil
      )
      WorkoutCompletionFlowView(
        presentation: presentation,
        studentID: studentID,
        initialPhase: phase,
        onFinish: {
          markReviewCompleted(
            for: workout.day.scheduledDate,
            setCount: workout.drafts.count
          )
          onReturnToToday()
        }
      )
    } else {
      Color.MeetPR.bgBase
    }
  }

  private var screenContent: TodayWorkoutScreen<TrainingCalendarView>.Content {
    switch viewModel.state {
    case .idle, .loading:
      if let workout = handedOffWorkout(for: selectedDayID) {
        .workout(
          TodayWorkoutPresentation(
            day: workout.day,
            drafts: workout.drafts,
            references: [:],
            videoStates: [:],
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
          started: started
        )
      )
    case .noPlan:
      .noPlan
    case .error(let message):
      .error(message)
    }
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
    guard let currentDay else { return false }
    return currentDay.id == StudentPlanSequence(days: viewModel.planDays).cursorDay?.id
  }

  private var selectedDayState: TodayWorkoutDayState {
    guard let currentDay else { return .current }
    if currentDay.completedAt != nil { return .completed(canUndo: canUndoCurrentDay) }
    return isEditable ? .current : .upcoming(previousDay: previousSequenceDay)
  }

  private var canUndoCurrentDay: Bool {
    guard let completedAt = currentDay?.completedAt else { return false }
    return WorkoutDatePolicy.gymDayRange(containing: Date()).contains(completedAt)
  }

  private var previousSequenceDay: StudentPlanDay? {
    let days = StudentPlanSequence(days: viewModel.planDays).orderedDays
    guard let currentDay, let index = days.firstIndex(where: { $0.id == currentDay.id }), index > 0
    else { return nil }
    return days[index - 1]
  }

  private var selectedTrainingDate: Date {
    currentDay?.scheduledDate ?? initialDate ?? Date()
  }

  private var weekCode: String {
    if viewModel.state == .noPlan {
      return "W—"
    }
    let title = TodayWorkoutTitleResolver.title(
      day: currentDay,
      planContext: viewModel.planContext,
      onboarding: viewModel.onboardingProfile
    )
    return title.split(separator: "·").first.map {
      String($0).trimmingCharacters(in: .whitespaces)
    } ?? "今日"
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

  private func setEntry(for target: EditingTarget) -> some View {
    SetEntrySheet(
      rowIndex: target.rowIndex,
      draft: target.draft,
      setNumber: target.setNumber,
      viewModel: viewModel,
      studentID: studentID,
      trainingDate: selectedTrainingDate,
      videoViewModel: videoViewModel,
      scrollToVideo: target.scrollToVideo
    )
  }

  private func openVideoAction(_ row: TodayWorkoutPresentation.Row) {
    guard isEditable else { return }
    switch SetVideoButtonDestination.resolve(
      for: videoIndicatorStatus(for: row.draft),
      cameraAvailable: cameraAvailable
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
      retryTargetSetLogID = row.draft.loggedSetID
    }
  }

  private func videoStates(
    for drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> [UUID: SetRow.VideoState] {
    Dictionary(
      uniqueKeysWithValues: drafts.compactMap { draft in
        guard let setLogID = draft.loggedSetID else { return nil }
        return (setLogID, setRowVideoState(for: draft))
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
    guard let setLogID = draft.loggedSetID else { return nil }
    return videoViewModel.rowStates[setLogID]
  }

  private func videoIndicatorStatus(
    for draft: TodayWorkoutViewModel.SetRowDraft
  ) -> VideoAttachment.Status? {
    if preparingVideoSetID == draft.id { return .pending }
    return videoRowState(for: draft)?.attachment.status
  }

  private var cameraAvailable: Bool {
    #if os(iOS)
      CameraRecorderView.isAvailable
    #else
      false
    #endif
  }

  private func beginDirectCamera(for draft: TodayWorkoutViewModel.SetRowDraft) {
    directCameraTarget = DirectCameraTarget(id: draft.id)
    if videoViewModel.hasConsented {
      showingDirectCamera = true
    } else {
      showingDirectCameraConsent = true
    }
  }

  private func attachDirectCameraVideo(
    sourceURL: URL,
    target: DirectCameraTarget
  ) async {
    let rowIndex = viewModel.currentDrafts?.firstIndex { $0.id == target.id }
    let liveDraft = rowIndex.flatMap { viewModel.currentDrafts?[$0] }
    let setLogID: UUID?
    if let loggedSetID = liveDraft?.loggedSetID {
      setLogID = loggedSetID
    } else if let rowIndex {
      setLogID = await viewModel.ensureLoggedSetID(rowIndex: rowIndex)
    } else {
      setLogID = nil
    }

    guard let setLogID else {
      try? FileManager.default.removeItem(at: sourceURL)
      videoViewModel.reportVideoProcessingFailure()
      preparingVideoSetID = nil
      return
    }
    await videoViewModel.attach(
      sourceURL: sourceURL,
      setLogID: setLogID,
      studentID: studentID,
      trainingDate: selectedTrainingDate
    )
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

  private var restTimerExplanationPresented: Binding<Bool> {
    Binding(
      get: { viewModel.showsRestTimerExplanation && editing == nil },
      set: { _ in }
    )
  }

  private var retryDialogPresented: Binding<Bool> {
    Binding(
      get: { retryTargetSetLogID != nil },
      set: { if !$0 { retryTargetSetLogID = nil } }
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

  private func openSetRefPicker() {
    guard !isPreparingSetRefPicker, let notifications else { return }
    isPreparingSetRefPicker = true
    setRefEntryErrorMessage = nil
    Task {
      let openedConversationID = await notifications.openCoachConversation()
      isPreparingSetRefPicker = false
      guard let openedConversationID else {
        setRefEntryErrorMessage = StudentStrings.trainingShareConversationFailed
        return
      }
      setRefPickerRoute = SetRefPickerRoute(conversationID: openedConversationID)
    }
  }

  private func loadWorkout(
    for dayID: UUID?,
    preloadedPlan: StudentPlanView? = nil
  ) async {
    await viewModel.load(
      dayID: dayID,
      studentID: studentID,
      preloadedPlan: preloadedPlan
    )
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
    await viewModel.load(dayID: dayID, studentID: studentID)
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

  private func consumePendingAutoStartIfReady() {
    let targetDayIsLoaded = isEditable && currentWorkout?.day.id == selectedDayID
    if autoStartGate.consumeIfReady(isTargetDateLoaded: targetDayIsLoaded) {
      started = true
    }
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
    planContext: TodayWorkoutPlanContext?,
    onboarding: OnboardingProfile?
  ) -> String {
    guard let day else { return "锻炼" }
    let weekday = "W\(day.weekNumber)D\(day.dayOfWeek)"
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

private struct DirectCameraTarget {
  let id: UUID
}

private struct SetRefPickerRoute: Identifiable {
  var id: UUID { conversationID }

  let conversationID: UUID
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
      hasAvailableSet: !drafts.isEmpty,
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
