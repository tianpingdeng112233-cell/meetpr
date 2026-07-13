// swiftlint:disable file_length type_body_length
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
  /// Bumped by the parent when the student taps the home 开始/继续 CTA, so the
  /// training tab jumps back to today instead of whatever past/future day was
  /// last browsed here.
  private let jumpToTodayToken: Int
  private let planRevision: Int
  @State private var viewModel: TodayWorkoutViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var videoViewModel: VideoAttachmentViewModel
  @State private var selectedDate: Date
  @State private var showingSummary = false
  @State private var editing: EditingTarget?
  @State private var retryTargetSetLogID: UUID?
  @State private var showingReadinessSheet = false
  /// Whether the slide-to-complete → 训练回顾 → 完成 flow has been finished for
  /// the loaded day; loaded from `SessionReviewStore` so the slide control does
  /// not re-arm after the review sheet closes (or the app restarts).
  @State private var reviewCompleted = false
  private let reviewStore: any SessionReviewStore = UserDefaultsSessionReviewStore()

  public init(
    studentID: UUID,
    date: Date = Date(),
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    onboarding: (any OnboardingProfileReading)? = nil,
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    videoUploads: VideoUploadServices? = nil,
    jumpToTodayToken: Int = 0,
    planRevision: Int = 0
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.jumpToTodayToken = jumpToTodayToken
    self.planRevision = planRevision
    self._selectedDate = State(initialValue: date)
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
      VStack(spacing: 0) {
        TrainingCalendarView(
          studentID: studentID,
          selectedDate: $selectedDate,
          plans: plans,
          logs: logs,
          planRevision: planRevision
        )
        .padding(.horizontal)
        .padding(.top)

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
      .background(Color.MeetPR.bg)
      .navigationTitle(navTitle)
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
          .foregroundStyle(readinessFiled ? Color.MeetPR.green : Color.MeetPR.fgSecondary)
        }
        .accessibilityLabel(readinessFiled ? "今日状态已填，点按修改" : "填写今日状态")

        Button {
          Task { await loadWorkout(for: selectedDate) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .accessibilityLabel("刷新")
      }
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
      if !Calendar.current.isDateInToday(selectedDate) {
        selectedDate = Date()
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
    return ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if !isEditable {
          readOnlyNotice(for: day.date)
        }

        if let activeIndex {
          activeSetHero(
            draft: drafts[activeIndex],
            rowIndex: activeIndex,
            setNumber: setNumber(for: drafts[activeIndex], in: drafts),
            totalSets: totalSets(for: drafts[activeIndex].planExerciseID, in: drafts),
            isEditable: isEditable)
        }

        ForEach(day.exercises) { exercise in
          exerciseTableCard(
            exercise: exercise,
            rows: rows(for: exercise, drafts: drafts),
            allDrafts: drafts,
            activeIndex: activeIndex,
            isEditable: isEditable)
        }

        completionControls(drafts: drafts, day: day, isEditable: isEditable)
      }
      .padding(16)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bg)
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
    // Anchored here (not on the slide control) so the review stays reachable
    // from the completion banner after the slide control is gone.
    .sheet(isPresented: $showingSummary) {
      SessionSummaryView(
        summary: StudentSessionSummary(drafts: drafts), date: day.date, studentID: studentID,
        onComplete: { markReviewCompleted(for: day.date) }
      )
    }
  }

  @ViewBuilder
  private func completionControls(
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    day: StudentPlanDay,
    isEditable: Bool
  ) -> some View {
    let dayComplete = !drafts.isEmpty && drafts.allSatisfy(\.completed)

    if dayComplete {
      DayCompletionBanner(totalSets: drafts.count) {
        showingSummary = true
      }
    }

    // Hidden only once the day is fully closed (all sets done AND the review
    // finished with 完成) — the banner then carries the 查看回顾 entry. If a set
    // is later un-checked the banner disappears, so the slide control must
    // return or the review becomes unreachable.
    if isEditable && !(dayComplete && reviewCompleted) {
      SlideToCompleteButton(title: "滑动完成今日训练") {
        showingSummary = true
      }
      .padding(.top, 4)
    }
  }

  private func markReviewCompleted(for date: Date) {
    reviewStore.markReviewCompleted(studentId: studentID, date: date)
    reviewCompleted = true
  }

  // MARK: - Read-only notice

  private func readOnlyNotice(for date: Date) -> some View {
    let isPast = WorkoutDatePolicy.isPast(date)
    return HStack(spacing: 8) {
      Image(systemName: isPast ? "clock.arrow.circlepath" : "eye")
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Text(isPast ? "历史记录 · 不可修改" : "未到训练日 · 仅预览")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Spacer()
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  // MARK: - Active set hero

  private func activeSetHero(
    draft: TodayWorkoutViewModel.SetRowDraft,
    rowIndex: Int,
    setNumber: Int,
    totalSets: Int,
    isEditable: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Eyebrow(
        "第 \(twoDigit(setNumber)) / \(twoDigit(totalSets)) 组")

      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Text(weightText(draft))
          .font(.system(size: 72, weight: .heavy).monospacedDigit())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("KG")
          .font(.system(size: 22, weight: .heavy))
          .foregroundStyle(Color.MeetPR.brandRed)
        Spacer()
        HStack(alignment: .lastTextBaseline, spacing: 2) {
          Text("×")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Color.MeetPR.fgSecondary)
          Text(targetRepsText(draft))
            .font(.system(size: 36, weight: .heavy).monospacedDigit())
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("次")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      .padding(.top, 12)

      Text("RPE")
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.brandRed)
        .padding(.top, 16)
      HStack(alignment: .lastTextBaseline, spacing: 8) {
        Text(StudentFormatting.decimal(currentRPE(draft)))
          .font(.system(size: 36, weight: .heavy).monospacedDigit())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("/ 10").font(.system(size: 12)).foregroundStyle(Color.MeetPR.fgTertiary)
      }

      if isEditable {
        recordActions(draft: draft, rowIndex: rowIndex, setNumber: setNumber)
          .padding(.top, 16)
      }
    }
    .padding(16)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  private func recordActions(
    draft: TodayWorkoutViewModel.SetRowDraft, rowIndex: Int, setNumber: Int
  ) -> some View {
    HStack(spacing: 8) {
      Button {
        editing = EditingTarget(
          id: draft.id,
          rowIndex: rowIndex,
          draft: draft,
          setNumber: setNumber,
          scrollToVideo: false)
      } label: {
        Text("记录此组")
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.bg)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(Color.MeetPR.fgPrimary)
          .clipShape(.rect(cornerRadius: 12))
      }
      .buttonStyle(.plain)

      Button {
        // A failed upload routes straight to retry: the set already cost the
        // student real fatigue and can't be re-done, so the recording must
        // never be one buried menu away (David, beta 2026-07-11).
        if let failedSetLogID = failedVideoSetLogID(for: draft) {
          retryTargetSetLogID = failedSetLogID
        } else {
          editing = EditingTarget(
            id: draft.id,
            rowIndex: rowIndex,
            draft: draft,
            setNumber: setNumber,
            scrollToVideo: true)
        }
      } label: {
        SetVideoUploadIndicator(
          status: videoRowState(for: draft)?.attachment.status,
          progress: videoRowState(for: draft)?.progress ?? 0,
          size: 20
        )
        .frame(width: 56, height: 48)
        .overlay {
          RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
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

  private func exerciseTableCard(
    exercise: StudentPlanExercise,
    rows: [TodayWorkoutViewModel.SetRowDraft],
    allDrafts: [TodayWorkoutViewModel.SetRowDraft],
    activeIndex: Int?,
    isEditable: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(exercise.exercise.name)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        if let reference = viewModel.exerciseReferences[exercise.exercise.id], reference.hasValue {
          Text(referenceText(reference))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }

      VStack(spacing: 0) {
        LazyVGrid(columns: columns, spacing: 0) {
          tableHeaderCell("#", leading: true)
          tableHeaderCell("重量")
          tableHeaderCell("次数")
          tableHeaderCell("RPE")
          Text("")
          Text("")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.MeetPR.border).frame(height: 1) }

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
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
    }
  }

  private func tableHeaderCell(_ text: String, leading: Bool = false) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      .tracking(0.8)
      .foregroundStyle(Color.MeetPR.fgTertiary)
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
      .buttonStyle(.plain)
    } else {
      setRowGrid(draft: draft, setNumber: setNumber, active: active)
    }
  }

  private func setRowGrid(
    draft: TodayWorkoutViewModel.SetRowDraft, setNumber: Int, active: Bool
  ) -> some View {
    let resolved = draft.completed || active
    let foreground: Color = resolved ? Color.MeetPR.fgPrimary : Color.MeetPR.fgTertiary
    return LazyVGrid(columns: columns, spacing: 0) {
      Text("\(setNumber)")
        .foregroundStyle(active ? Color.MeetPR.brandRed : Color.MeetPR.fgTertiary)
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
          status: videoRowState(for: draft)?.attachment.status,
          progress: videoRowState(for: draft)?.progress ?? 0,
          size: 16
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .font(.system(size: 16, design: .monospaced))
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(active ? Color.MeetPR.surface2 : Color.clear)
    .overlay(alignment: .bottom) { Rectangle().fill(Color.MeetPR.border).frame(height: 1) }
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
    if draft.failed { return Color.MeetPR.amber }
    return draft.completed ? Color.MeetPR.green : Color.MeetPR.fgTertiary
  }

  private func videoRowState(
    for draft: TodayWorkoutViewModel.SetRowDraft
  ) -> VideoAttachmentViewModel.RowState? {
    guard let setLogID = draft.loggedSetID else { return nil }
    return videoViewModel.rowStates[setLogID]
  }

  private func failedVideoSetLogID(for draft: TodayWorkoutViewModel.SetRowDraft) -> UUID? {
    guard videoRowState(for: draft)?.attachment.status == .failed else { return nil }
    return draft.loggedSetID
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

  private func twoDigit(_ value: Int) -> String { String(format: "%02d", value) }

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
    Calendar.current.isDateInToday(selectedDate) ? "今日休息" : "这天休息"
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
    guard Calendar.current.isDateInToday(date) else { return }
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
// swiftlint:enable file_length type_body_length
