// swiftlint:disable file_length type_body_length
import Analytics
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
  private let streak: any StudentStreakRepository
  /// Bumped by the parent when the student taps the home 开始/继续 CTA, so the
  /// training tab jumps back to today instead of whatever past/future day was
  /// last browsed here.
  private let jumpToTodayToken: Int
  private let planRevision: Int
  private var workoutStartedAt: Binding<Date?>
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onOpenFeedbackNotification: () -> Void
  private let onOpenEvaluationNotification: () -> Void
  @State private var viewModel: TodayWorkoutViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var videoViewModel: VideoAttachmentViewModel
  @State private var selectedDate: Date
  @State private var showingSummary = false
  /// Two-state flow (§4.2): false = overview (state A), true = recording (B).
  @State private var sessionStarted = false
  @State private var editing: EditingTarget?
  @State private var directCameraTarget: DirectCameraTarget?
  @State private var showingDirectCameraConsent = false
  @State private var showingDirectCamera = false
  @State private var preparingVideoSetID: UUID?
  @State private var retryTargetSetLogID: UUID?
  @State private var showingReadinessSheet = false
  @State private var showingNotifications = false
  @State private var conversationID: UUID?
  @State private var collapsedExerciseIDs: Set<UUID> = []
  /// Whether the hold-to-complete → 训练回顾 → 完成 flow has been finished for
  /// the loaded day; loaded from `SessionReviewStore` so the hold control does
  /// not re-arm after the review sheet closes (or the app restarts).
  @State private var reviewCompleted = false
  private let reviewStore: any SessionReviewStore = UserDefaultsSessionReviewStore()

  public init(
    studentID: UUID,
    date: Date? = nil,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    onboarding: (any OnboardingProfileReading)? = nil,
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    streak: any StudentStreakRepository = InMemoryStudentStreakRepository(current: 12),
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    videoUploads: VideoUploadServices? = nil,
    jumpToTodayToken: Int = 0,
    planRevision: Int = 0,
    workoutStartedAt: Binding<Date?> = .constant(nil),
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {},
    onOpenFeedbackNotification: @escaping () -> Void = {},
    onOpenEvaluationNotification: @escaping () -> Void = {}
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.streak = streak
    self.jumpToTodayToken = jumpToTodayToken
    self.planRevision = planRevision
    self.workoutStartedAt = workoutStartedAt
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onOpenFeedbackNotification = onOpenFeedbackNotification
    self.onOpenEvaluationNotification = onOpenEvaluationNotification
    // nil = open on "today", which is the gym-day (04:00 cutoff) — a cold
    // start at 00:30 lands on the still-editable previous calendar day.
    self._selectedDate = State(initialValue: date ?? WorkoutDatePolicy.gymDayToday())
    self._viewModel = State(
      initialValue: TodayWorkoutViewModel(
        plans: plans,
        logs: logs,
        e1rm: e1rm,
        onboarding: onboarding,
        restTimerSettings: restTimerSettings
      ))
    self._readinessViewModel = State(
      initialValue: ReadinessCheckinViewModel(repo: readiness))
    self._videoViewModel = State(
      initialValue: VideoAttachmentViewModel(manager: (videoUploads ?? .demo()).manager))
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        HStack(spacing: MeetPRSpacing.sm) {
          MeetPRMark(size: 30)
          Text(navTitle)
            .font(.MeetPR.display(size: 20, weight: .extraBold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
        }
        .padding(.horizontal, MeetPRSpacing.base)
        .padding(.top, MeetPRSpacing.point6)
        .meetPRRiseIn(index: 0)

        // The handoff spec's training screen has no calendar (David
        // 2026-07-26): day browsing lives on 今日's week strip, this tab is
        // the overview → recording flow only.
        Group {
          switch viewModel.state {
          case .idle, .loading:
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          // One pattern, one branch: .loaded → .recording → .loaded round-trips
          // during every persist, and separate cases are separate structural
          // identities — SwiftUI tore down the subtree, which dismissed and
          // re-presented the set-entry sheet with reset fields whenever a
          // video attach minted a set log (beta 2026-07-11).
          case .loaded(let day, let drafts), .recording(let day, let drafts, _):
            workout(day: day, drafts: drafts)
          case .rest:
            ContentUnavailableView(restTitle, systemImage: "bed.double", description: Text("看本周计划"))
          case .error(let message):
            ContentUnavailableView(
              "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .background(Color.MeetPR.bgBase)
      .meetPRHideSystemTabBar()
      .navigationTitle("")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        Button {
          showingReadinessSheet = true
        } label: {
          Image(
            systemName: readinessFiled ? "heart.text.square.fill" : "heart.text.square"
          )
          .foregroundStyle(readinessFiled ? Color.MeetPR.success : Color.MeetPR.textSecondary)
        }
        .accessibilityLabel(readinessFiled ? "今日状态已填，点按修改" : "填写今日状态")

        Button {
          Task { await loadWorkout(for: selectedDate) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .accessibilityLabel("刷新")

        if let notifications {
          StudentNotificationBell(coordinator: notifications) {
            showingNotifications = true
          }
        }
      }
      .modifier(
        OptionalStudentNotificationHostModifier(
          coordinator: notifications,
          showsNotifications: $showingNotifications,
          conversationID: $conversationID,
          onOpenPlan: onOpenPlanNotification,
          onOpenFeedback: onOpenFeedbackNotification,
          onOpenEvaluation: onOpenEvaluationNotification
        )
      )
    }
    .overlay(alignment: .top) {
      if let event = viewModel.pendingPRBanner {
        PRBanner(
          event: event,
          exerciseName: viewModel.exerciseName(for: event.exerciseId),
          onDismiss: {
            Task { await viewModel.acknowledgePendingPR() }
          }
        )
        .padding(.top, MeetPRSpacing.sm)
      }
    }
    .animation(.spring(duration: 0.35), value: viewModel.pendingPRBanner)
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
    .animation(.spring(duration: 0.3), value: viewModel.restTimer)
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
      "视频上传失败", isPresented: retryDialogPresented, titleVisibility: .visible
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
          CameraVideoPicker(
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
                await VideoLibrarySaver.save(url)
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
        await loadWorkout(for: selectedDate)
      }
      // Outside the idle guard: a cancelled first .task can strand state in
      // .loading, and row video indicators need the backfill + event stream
      // regardless. start() is idempotent.
      await videoViewModel.start(studentID: studentID)
      if isFirstLoad {
        // Re-surface a PR banner the student never dismissed (spec 028 §5);
        // delayed so the tab renders first.
        try? await Task.sleep(for: .seconds(1.5))
        await viewModel.surfaceUnacknowledgedPR(studentID: studentID)
      }
    }
    .onChange(of: selectedDate) { _, newDate in
      // The open editor belongs to the day being left — a stale rowIndex
      // against reloaded drafts would edit the wrong set.
      editing = nil
      Task { await loadWorkout(for: newDate) }
    }
    .onChange(of: jumpToTodayToken) { _, _ in
      // "Today" is the gym-day (04:00 cutoff), so jumping never leaves the
      // editable day during the 00:00–03:59 window.
      if !WorkoutDatePolicy.isEditable(selectedDate) {
        selectedDate = WorkoutDatePolicy.gymDayToday()
      }
    }
    .onChange(of: planRevision) { _, _ in
      editing = nil
      Task { await loadWorkout(for: selectedDate) }
    }
  }

  private var actionErrorPresented: Binding<Bool> {
    Binding(
      get: { viewModel.actionErrorMessage != nil },
      set: { if !$0 { viewModel.clearActionError() } }
    )
  }

  private var restTimerExplanationPresented: Binding<Bool> {
    Binding(
      // Gated on `editing == nil`: the first completed set is recorded inside
      // SetEntrySheet, and racing a second sheet against it has no documented
      // ordering. The flag only clears on 知道了, so the card presents right
      // after the editor dismisses.
      get: { viewModel.showsRestTimerExplanation && editing == nil },
      set: { _ in }
    )
  }

  // MARK: - Workout body

  private func workout(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> some View {
    let activeIndex = drafts.firstIndex { !$0.completed }
    // Only today's session is writable. Past days are a read-only record and
    // future days a preview, so logging/completing can't be triggered by
    // mistake (previously any browsed day accepted set records + completion).
    let isEditable = WorkoutDatePolicy.isEditable(day.date)
    // Handoff §4.2 two-state flow: state A is a pure overview (no set rows),
    // state B is the recording surface. Any logged set re-enters B directly.
    let isOverview =
      isEditable && !sessionStarted && activeIndex != nil && !drafts.contains(where: \.completed)
    return ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
        if !isEditable {
          readOnlyNotice(for: day.date)
        }

        if isOverview {
          overviewHero(day: day, drafts: drafts)
            .meetPRRiseIn(index: 2)
        } else {
          recordingContent(
            day: day, drafts: drafts, activeIndex: activeIndex, isEditable: isEditable
          )
        }
      }
      .padding(MeetPRSpacing.space4)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bgBase)
    .sheet(item: $editing) { target in
      SetEntrySheet(
        rowIndex: target.rowIndex,
        draft: target.draft,
        setNumber: target.setNumber,
        viewModel: viewModel,
        studentID: studentID,
        videoViewModel: videoViewModel,
        scrollToVideo: target.scrollToVideo
      )
    }
    // Anchored here (not on the hold control) so the review stays reachable
    // from the completion banner after the hold control is gone.
    .sheet(isPresented: $showingSummary) {
      SessionSummaryView(
        summary: StudentSessionSummary(drafts: drafts), date: day.date, studentID: studentID,
        streak: streak,
        onComplete: { markReviewCompleted(for: day.date, setCount: drafts.count) }
      )
    }
  }

  private func exerciseSections(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    activeIndex: Int?,
    isEditable: Bool
  ) -> some View {
    ForEach(TodayWorkoutExerciseSection.sections(for: day.exercises)) { section in
      Text(section.title)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.textTertiary)

      ForEach(section.exercises) { exercise in
        exerciseTableCard(
          exercise: exercise,
          rows: rows(for: exercise, drafts: drafts),
          allDrafts: drafts,
          activeIndex: activeIndex,
          isEditable: isEditable)
      }
    }
  }

  @ViewBuilder
  private func completionControls(
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    day: StudentPlanDay,
    isEditable: Bool
  ) -> some View {
    let dayComplete = !drafts.isEmpty && drafts.allSatisfy(\.completed)

    // On an editable day the banner (with its 查看回顾 entry) must not appear
    // until the slide confirmation closes the day. Read-only days have no slide
    // control, so the banner stays as the only entry to the review there.
    if dayComplete && (reviewCompleted || !isEditable) {
      DayCompletionBanner(totalSets: drafts.count) {
        showingSummary = true
      }
    }

    // Hidden only once the day is fully closed (all sets done AND the review
    // finished with 完成) — the banner then carries the 查看回顾 entry. If a set
    // is later un-checked the banner disappears, so the hold control must
    // return or the review becomes unreachable.
    if isEditable && !(dayComplete && reviewCompleted) {
      HoldToCompleteButton(title: "长按 · 完成今日训练") {
        showingSummary = true
      }
      .padding(.top, MeetPRSpacing.space1)
    }
  }

  private func markReviewCompleted(for date: Date, setCount: Int) {
    reviewStore.markReviewCompleted(studentId: studentID, date: date)
    reviewCompleted = true
    guard let startedAt = workoutStartedAt.wrappedValue else { return }
    Analytics.shared.workoutLogSaved(
      setCount: setCount,
      durationMilliseconds: max(0, Int(Date().timeIntervalSince(startedAt) * 1_000)))
    workoutStartedAt.wrappedValue = nil
  }

  /// State B: the active-set hero plus per-exercise tables. Freshly revealed
  /// sections fan in on the spec's 360ms/90ms stagger.
  @ViewBuilder
  private func recordingContent(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    activeIndex: Int?,
    isEditable: Bool
  ) -> some View {
    let delay =
      sessionStarted ? MeetPRMotion.recordingRevealDelay : MeetPRMotion.riseInitialDelay
    let stagger =
      sessionStarted ? MeetPRMotion.recordingRevealStagger : MeetPRMotion.riseStagger
    if let activeIndex {
      activeSetHero(
        day: day, drafts: drafts, activeIndex: activeIndex, isEditable: isEditable
      )
      .meetPRRiseIn(index: 2)
    }

    exerciseSections(
      day: day, drafts: drafts, activeIndex: activeIndex, isEditable: isEditable
    )
    .meetPRRiseIn(index: 3, initialDelay: delay, stagger: stagger)

    completionControls(drafts: drafts, day: day, isEditable: isEditable)
      .meetPRRiseIn(index: 4, initialDelay: delay, stagger: stagger)
  }

  // MARK: - Overview (state A)

  /// Handoff §4.2 state A: hero summary plus exercise preview rows, no set
  /// tables, closed by the big start button. Estimated length assumes ~4
  /// minutes per set including rest.
  private func overviewHero(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> some View {
    let exerciseCount = day.exercises.count
    let estMinutes = max(10, drafts.count * 4)
    return VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(navTitle)
          .font(.MeetPR.display(size: 22, weight: .extraBold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text("共 \(exerciseCount) 个动作 · 约 \(estMinutes) 分钟")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .medium))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }

      VStack(spacing: MeetPRSpacing.space2) {
        ForEach(Array(day.exercises.enumerated()), id: \.element.id) { pair in
          overviewPreviewRow(number: pair.offset + 1, exercise: pair.element)
        }
      }

      BrandPrimaryButton(
        "开始第一组",
        systemImage: "play.fill",
        showsShimmer: true,
        isFullWidth: true
      ) {
        withAnimation(MeetPRMotion.screen) { sessionStarted = true }
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceFocus)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .overlay(alignment: .leading) {
      LinearGradient(
        colors: [Color.MeetPR.gold300, Color.MeetPR.gold400, Color.MeetPR.gold500],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(width: 3)
    }
    .meetPRGoldGlow()
  }

  private func overviewPreviewRow(number: Int, exercise: StudentPlanExercise) -> some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Text("\(number)")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(width: 22, height: 22)
        .background(Color.MeetPR.goldSoft)
        .clipShape(.rect(cornerRadius: 7))
      Text(exercise.exercise.name)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineLimit(1)
      Spacer(minLength: MeetPRSpacing.space2)
      Text("\(exercise.prescribedSets.count) 组")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .medium))
        .foregroundStyle(Color.MeetPR.textTertiary)
        .lineLimit(1)
    }
    .padding(.horizontal, MeetPRSpacing.point13)
    .padding(.vertical, MeetPRSpacing.point11)
    .frame(maxWidth: .infinity, alignment: .leading)
    .meetPRCardSurface(.inset)
  }

  // MARK: - Read-only notice

  private func readOnlyNotice(for date: Date) -> some View {
    let isPast = WorkoutDatePolicy.isPast(date)
    return HStack(spacing: MeetPRSpacing.space2) {
      Image(systemName: isPast ? "clock.arrow.circlepath" : "eye")
        .foregroundStyle(Color.MeetPR.textSecondary)
      Text(isPast ? "历史记录 · 不可修改" : "未到训练日 · 仅预览")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.textSecondary)
      Spacer()
    }
    .padding(MeetPRSpacing.space3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
        Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }

  // MARK: - Active set hero

  private func activeSetHero(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    activeIndex: Int,
    isEditable: Bool
  ) -> some View {
    let draft = drafts[activeIndex]
    let rowIndex = activeIndex
    let setNumber = setNumber(for: draft, in: drafts)
    let totalSets = totalSets(for: draft.planExerciseID, in: drafts)
    let exerciseNote = exerciseNote(for: draft.planExerciseID, in: day)
    return VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space2) {
        Text(draft.exerciseName)
          .font(.MeetPR.display(size: 22, weight: .extraBold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text("\(setNumber)/\(totalSets)")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size15, weight: .bold).monospacedDigit())
          .foregroundStyle(Color.MeetPR.textSecondary)
      }

      heroTargetRow(draft: draft)
        .padding(.top, MeetPRSpacing.space3)

      if let exerciseNote {
        CoachNotePill(note: exerciseNote)
          .padding(.top, MeetPRSpacing.point10)
      }

      Text("RPE")
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.gold500)
        .padding(.top, MeetPRSpacing.space4)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space2) {
        Text(StudentFormatting.decimal(currentRPE(draft)))
          .font(.MeetPR.display(size: 20, weight: .extraBold).monospacedDigit())
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text("/ 10").font(.MeetPR.system(size: MeetPRFontMetrics.size12)).foregroundStyle(
          Color.MeetPR.textTertiary)
      }

      if isEditable {
        recordActions(draft: draft, rowIndex: rowIndex, setNumber: setNumber)
          .padding(.top, MeetPRSpacing.space4)
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceFocus)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .overlay(alignment: .leading) {
      LinearGradient(
        colors: [Color.MeetPR.gold300, Color.MeetPR.gold400, Color.MeetPR.gold500],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(width: 3)
    }
    .meetPRGoldGlow()
  }

  private func heroTargetRow(draft: TodayWorkoutViewModel.SetRowDraft) -> some View {
    HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point6) {
      Text(weightText(draft))
        .font(.MeetPR.display(size: 54, weight: .extraBold).monospacedDigit())
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("KG")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size22, weight: .heavy))
        .foregroundStyle(Color.MeetPR.gold500)
      Spacer()
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point2) {
        Text("×")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size24, weight: .bold))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Text(targetRepsText(draft))
          .font(.MeetPR.system(size: MeetPRFontMetrics.size36, weight: .heavy).monospacedDigit())
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text("次")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
    }
  }

  private func recordActions(
    draft: TodayWorkoutViewModel.SetRowDraft, rowIndex: Int, setNumber: Int
  ) -> some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Button {
        editing = EditingTarget(
          id: draft.id,
          rowIndex: rowIndex,
          draft: draft,
          setNumber: setNumber,
          scrollToVideo: false)
      } label: {
        Text("记录此组")
          .font(.MeetPR.body(size: 15, weight: .bold))
          .foregroundStyle(Color.MeetPR.ctaText)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(Color.MeetPR.ctaBackground)
          .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
      }
      .buttonStyle(PressScaleButtonStyle())

      Button {
        switch SetVideoButtonDestination.resolve(
          for: videoRowState(for: draft)?.attachment.status,
          cameraAvailable: cameraAvailable
        ) {
        case .camera:
          beginDirectCamera(for: draft)
        case .details:
          editing = EditingTarget(
            id: draft.id,
            rowIndex: rowIndex,
            draft: draft,
            setNumber: setNumber,
            scrollToVideo: true)
        case .retry:
          // A failed upload routes straight to retry: the set already cost the
          // student real fatigue and can't be re-done, so the recording must
          // never be one buried menu away (David, beta 2026-07-11).
          retryTargetSetLogID = draft.loggedSetID
        }
      } label: {
        SetVideoUploadIndicator(
          status: videoIndicatorStatus(for: draft),
          progress: videoRowState(for: draft)?.progress ?? 0,
          size: 20
        )
        .frame(width: 56, height: 48)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
            Color.MeetPR.borderDefault, lineWidth: 1)
        }
      }
      .buttonStyle(PressScaleButtonStyle())
      .disabled(preparingVideoSetID == draft.id)
    }
  }

  // MARK: - Per-exercise set table

  private let columns: [GridItem] = [
    GridItem(.fixed(28), alignment: .leading),
    GridItem(.flexible(), alignment: .trailing),
    GridItem(.flexible(), alignment: .trailing),
    GridItem(.flexible(), alignment: .trailing),
    GridItem(.fixed(36), alignment: .trailing),
    GridItem(.fixed(28), alignment: .trailing),
  ]

  // swiftlint:disable:next function_body_length
  private func exerciseTableCard(
    exercise: StudentPlanExercise,
    rows: [TodayWorkoutViewModel.SetRowDraft],
    allDrafts: [TodayWorkoutViewModel.SetRowDraft],
    activeIndex: Int?,
    isEditable: Bool
  ) -> some View {
    let allCompleted = !rows.isEmpty && rows.allSatisfy(\.completed)
    let isCollapsed = collapsedExerciseIDs.contains(exercise.id)

    return ZStack(alignment: .top) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
            Text(exercise.exercise.name)
              .font(Font.MeetPR.bodyEmphasis)
              .foregroundStyle(Color.MeetPR.textPrimary)
            if let reference = viewModel.exerciseReferences[exercise.exercise.id],
              reference.hasValue
            {
              Text(referenceText(reference))
                .font(Font.MeetPR.footnote)
                .foregroundStyle(Color.MeetPR.textTertiary)
            }
          }

          Spacer()

          if allCompleted {
            Button {
              collapsedExerciseIDs.insert(exercise.id)
            } label: {
              HStack(spacing: MeetPRSpacing.space1) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(Color.MeetPR.success)
                Image(systemName: "chevron.up")
                  .font(Font.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
                  .foregroundStyle(Color.MeetPR.textFaint)
              }
              .font(.title3)
              .frame(
                minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("收起 \(exercise.exercise.name)")
          }
        }

        // Review path: with no active set there is no hero card, so a finished
        // (or browsed read-only) day surfaces each exercise's note here instead.
        if let note = CoachNoteDisplay.reviewNote(activeIndex: activeIndex, notes: exercise.notes) {
          CoachNotePill(note: note)
        }

        VStack(spacing: MeetPRSpacing.zero) {
          LazyVGrid(columns: columns, spacing: MeetPRSpacing.zero) {
            tableHeaderCell("#", leading: true)
            tableHeaderCell("重量")
            tableHeaderCell("次数")
            tableHeaderCell("RPE")
            Text("")
            Text("")
          }
          .padding(.horizontal, MeetPRSpacing.space4)
          .padding(.vertical, MeetPRSpacing.point10)
          .overlay(alignment: .bottom) {
            Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1)
          }

          ForEach(Array(rows.enumerated()), id: \.element.id) { offset, draft in
            let index = allDrafts.firstIndex { $0.id == draft.id } ?? 0
            setRow(
              draft: draft,
              rowIndex: index,
              setNumber: SetDisplayNumber.number(atOffset: offset),
              active: activeIndex == index,
              isEditable: isEditable)
          }
        }
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.control)
            .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
        }
      }
      .meetPRRollUp(isCollapsed: isCollapsed)
      .allowsHitTesting(!isCollapsed)

      if isCollapsed {
        collapsedExercisePill(exercise: exercise, completedSetCount: rows.count)
          .meetPRPillRiseIn()
      }
    }
    .frame(maxHeight: isCollapsed ? 48 : nil, alignment: .top)
    .clipped()
    .onAppear {
      if allCompleted {
        collapsedExerciseIDs.insert(exercise.id)
      }
    }
    .onChange(of: allCompleted) { wasCompleted, isCompleted in
      if isCompleted, !wasCompleted {
        collapsedExerciseIDs.insert(exercise.id)
      } else if !isCompleted {
        collapsedExerciseIDs.remove(exercise.id)
      }
    }
  }

  private func collapsedExercisePill(
    exercise: StudentPlanExercise,
    completedSetCount: Int
  ) -> some View {
    Button {
      collapsedExerciseIDs.remove(exercise.id)
    } label: {
      HStack(spacing: MeetPRSpacing.space3) {
        Image(systemName: "checkmark")
          .font(Font.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.success)
          .frame(width: 22, height: 22)
          .background(Color.MeetPR.successSoft)
          .clipShape(.circle)

        Text(exercise.exercise.name)
          .font(Font.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textSecondary)

        Spacer(minLength: MeetPRSpacing.space2)

        Text("\(completedSetCount) 组完成")
          .font(Font.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textFaint)

        Image(systemName: "chevron.down")
          .font(Font.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textDisabled)
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .frame(minHeight: 48)
      .background(Color.MeetPR.bgInset)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel("展开 \(exercise.exercise.name)，\(completedSetCount) 组完成")
  }

  private func exerciseNote(for planExerciseID: UUID, in day: StudentPlanDay) -> String? {
    CoachNoteDisplay.text(day.exercises.first { $0.id == planExerciseID }?.notes)
  }

  private func tableHeaderCell(_ text: String, leading: Bool = false) -> some View {
    Text(text)
      .font(.MeetPR.system(size: MeetPRFontMetrics.size10, weight: .medium, design: .monospaced))
      .tracking(0.8)
      .foregroundStyle(Color.MeetPR.textTertiary)
      .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
  }

  @ViewBuilder
  private func setRow(
    draft: TodayWorkoutViewModel.SetRowDraft,
    rowIndex: Int,
    setNumber: Int,
    active: Bool,
    isEditable: Bool
  ) -> some View {
    if isEditable {
      Button {
        editing = EditingTarget(
          id: draft.id,
          rowIndex: rowIndex,
          draft: draft,
          setNumber: setNumber,
          scrollToVideo: false)
      } label: {
        setRowGrid(draft: draft, setNumber: setNumber, active: active)
      }
      .buttonStyle(PressScaleButtonStyle())
    } else {
      setRowGrid(draft: draft, setNumber: setNumber, active: active)
    }
  }

  private func setRowGrid(
    draft: TodayWorkoutViewModel.SetRowDraft, setNumber: Int, active: Bool
  ) -> some View {
    let resolved = draft.completed || active
    let foreground: Color = resolved ? Color.MeetPR.textPrimary : Color.MeetPR.textTertiary
    return LazyVGrid(columns: columns, spacing: MeetPRSpacing.zero) {
      Text("\(setNumber)")
        .foregroundStyle(active ? Color.MeetPR.gold500 : Color.MeetPR.textTertiary)
      Text(weightText(draft)).fontWeight(active ? .bold : .regular).foregroundStyle(foreground)
      Text(repsText(draft)).foregroundStyle(foreground)
      Text(rpeText(draft)).foregroundStyle(foreground)
      Text(statusMark(draft)).foregroundStyle(statusColor(draft))
      // A failed upload intercepts the icon tap and goes straight to retry
      // (the row itself still opens the editor); other states fall through.
      if let failedSetLogID = failedVideoSetLogID(for: draft) {
        SetVideoUploadIndicator(status: .failed, progress: 0, size: 16)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .onTapGesture { retryTargetSetLogID = failedSetLogID }
      } else {
        SetVideoUploadIndicator(
          status: videoIndicatorStatus(for: draft),
          progress: videoRowState(for: draft)?.progress ?? 0,
          size: 16
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .font(.MeetPR.system(size: MeetPRFontMetrics.size16, design: .monospaced))
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .background(active ? Color.MeetPR.surfaceElevated : Color.clear)
    .overlay(alignment: .bottom) { Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1) }
    .contentShape(Rectangle())
  }

  // MARK: - Value formatting

  private func weightText(_ draft: TodayWorkoutViewModel.SetRowDraft) -> String {
    guard let weight = draft.actualWeight ?? draft.prescribed.weightKg else { return "—" }
    return StudentFormatting.decimal(weight)
  }

  private func targetRepsText(_ draft: TodayWorkoutViewModel.SetRowDraft) -> String {
    guard let reps = draft.prescribed.reps ?? draft.prescribed.repsMax else { return "—" }
    return "\(reps)"
  }

  private func repsText(_ draft: TodayWorkoutViewModel.SetRowDraft) -> String {
    guard let reps = draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax else {
      return "—"
    }
    return "\(reps)"
  }

  private func rpeText(_ draft: TodayWorkoutViewModel.SetRowDraft) -> String {
    guard let rpe = draft.actualRPE else { return "—" }
    return StudentFormatting.decimal(rpe)
  }

  private func currentRPE(_ draft: TodayWorkoutViewModel.SetRowDraft) -> Decimal {
    draft.actualRPE ?? draft.prescribed.rpe ?? 8
  }

  private func statusMark(_ draft: TodayWorkoutViewModel.SetRowDraft) -> String {
    if draft.failed { return "✗" }
    return draft.completed ? "✓" : "○"
  }

  private func statusColor(_ draft: TodayWorkoutViewModel.SetRowDraft) -> Color {
    if draft.failed { return Color.MeetPR.danger }
    return draft.completed ? Color.MeetPR.success : Color.MeetPR.textTertiary
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

  private func failedVideoSetLogID(for draft: TodayWorkoutViewModel.SetRowDraft) -> UUID? {
    guard videoRowState(for: draft)?.attachment.status == .failed else { return nil }
    return draft.loggedSetID
  }

  private var cameraAvailable: Bool {
    #if os(iOS)
      CameraVideoPicker.isAvailable
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
      studentID: studentID
    )
    preparingVideoSetID = nil
  }

  private var retryDialogPresented: Binding<Bool> {
    Binding(
      get: { retryTargetSetLogID != nil },
      set: { if !$0 { retryTargetSetLogID = nil } }
    )
  }

  private func referenceText(_ reference: ExerciseReference) -> String {
    var parts: [String] = []
    if let last = reference.last {
      parts.append("上次 \(StudentFormatting.kilograms(last.weightKg))kg×\(last.reps)")
    }
    if let best = reference.best {
      parts.append("最佳 \(StudentFormatting.kilograms(best.weightKg))kg×\(best.reps)")
    }
    return parts.joined(separator: " · ")
  }

  // MARK: - Derived

  private var navTitle: String {
    TodayWorkoutTitleResolver.title(
      day: currentDay,
      planContext: viewModel.planContext,
      onboarding: viewModel.onboardingProfile
    )
  }

  private var currentDay: StudentPlanDay? {
    switch viewModel.state {
    case .loaded(let day, _): return day
    case .recording(let day, _, _): return day
    default: return nil
    }
  }

  private func totalSets(
    for planExerciseID: UUID, in drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> Int {
    drafts.filter { $0.planExerciseID == planExerciseID }.count
  }

  private func setNumber(
    for draft: TodayWorkoutViewModel.SetRowDraft,
    in drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> Int {
    let exerciseRows = drafts.filter { $0.planExerciseID == draft.planExerciseID }
    return SetDisplayNumber.number(for: draft, in: exerciseRows)
  }

  private var restTitle: String {
    WorkoutDatePolicy.isEditable(selectedDate) ? "今日休息" : "这天休息"
  }

  private var readinessFiled: Bool {
    if case .done = readinessViewModel.gate { return true }
    return false
  }

  private var readinessPrefill: ReadinessCheckin? {
    if case .done(let checkin) = readinessViewModel.gate { return checkin }
    return nil
  }

  private func rows(
    for exercise: StudentPlanExercise,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> [TodayWorkoutViewModel.SetRowDraft] {
    drafts.filter { $0.planExerciseID == exercise.id }
  }

  private func loadWorkout(for date: Date) async {
    await viewModel.load(date: date, studentID: studentID)
    // Rapid date switches can finish loads out of order; only the load for the
    // still-selected day may set the flag, or a stale day's review state leaks
    // onto the visible one.
    if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
      reviewCompleted = reviewStore.didCompleteReview(studentId: studentID, date: date)
    }
    await refreshReadinessStatus(for: date)
  }

  // Check-in is opt-in via the toolbar heart; the sheet must never
  // auto-present (product call 2026-07-11 — coaches don't consume the data
  // yet, and the every-session interruption outweighed it). Still load the
  // gate so the heart reflects today's filed state.
  private func refreshReadinessStatus(for date: Date) async {
    guard WorkoutDatePolicy.isEditable(date) else { return }
    await readinessViewModel.load(studentId: studentID)
  }
}

enum TodayWorkoutTitleResolver {
  static func title(
    day: StudentPlanDay?,
    planContext: TodayWorkoutPlanContext?,
    onboarding: OnboardingProfile?
  ) -> String {
    guard let day else { return "锻炼" }
    let dayNumber = mondayOffset(day.date) + 1
    let weekday = planContext.map { "W\($0.weekIndex)D\(dayNumber)" } ?? "今日"
    let family = day.exercises.lazy.compactMap {
      resolveCompetitionFamily(exercise: $0.exercise, onboarding: onboarding)
    }.first
    guard let lift = family?.studentDisplayName else { return weekday }
    return "\(weekday) · \(lift)"
  }

  private static func mondayOffset(_ date: Date) -> Int {
    let weekday = Calendar.current.component(.weekday, from: date)  // 1=Sun…7=Sat
    return (weekday + 5) % 7
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
// swiftlint:enable file_length type_body_length
