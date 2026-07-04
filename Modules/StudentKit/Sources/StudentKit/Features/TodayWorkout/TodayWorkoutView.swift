// swiftlint:disable file_length type_body_length function_body_length
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
  @State private var viewModel: TodayWorkoutViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var videoViewModel: VideoAttachmentViewModel
  @State private var selectedDate: Date
  @State private var showingSummary = false
  @State private var editing: EditingTarget?
  @State private var showingReadinessSheet = false

  public init(
    studentID: UUID,
    date: Date = Date(),
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    videoUploads: VideoUploadServices? = nil,
    jumpToTodayToken: Int = 0
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.jumpToTodayToken = jumpToTodayToken
    self._selectedDate = State(initialValue: date)
    self._viewModel = State(
      initialValue: TodayWorkoutViewModel(plans: plans, logs: logs, e1rm: e1rm))
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
          logs: logs
        )
        .padding(.horizontal)
        .padding(.top)

        Group {
          switch viewModel.state {
          case .idle, .loading:
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          case .loaded(let day, let drafts):
            workout(day: day, drafts: drafts)
          case .recording(let day, let drafts, _):
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
    .sheet(isPresented: $showingReadinessSheet) {
      ReadinessCheckinSheet(
        studentID: studentID,
        viewModel: readinessViewModel,
        prefill: readinessPrefill,
        onClose: { showingReadinessSheet = false }
      )
      .presentationDetents([.large])
    }
    .task {
      if viewModel.state == .idle {
        await loadWorkout(for: selectedDate)
        await videoViewModel.start(studentID: studentID)

        // Re-surface a PR banner the student never dismissed (spec 028 §5);
        // delayed so the tab renders first.
        try? await Task.sleep(for: .seconds(1.5))
        await viewModel.surfaceUnacknowledgedPR(studentID: studentID)
      }
    }
    .onChange(of: selectedDate) { _, newDate in
      Task { await loadWorkout(for: newDate) }
    }
    .onChange(of: jumpToTodayToken) { _, _ in
      if !Calendar.current.isDateInToday(selectedDate) {
        selectedDate = Date()
      }
    }
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

        if !drafts.isEmpty && drafts.allSatisfy(\.completed) {
          DayCompletionBanner(totalSets: drafts.count)
        }

        if isEditable {
          SlideToCompleteButton(title: "滑动完成今日训练") {
            showingSummary = true
          }
          .padding(.top, 4)
          .sheet(isPresented: $showingSummary) {
            SessionSummaryView(
              summary: StudentSessionSummary(drafts: drafts), date: day.date, studentID: studentID)
          }
        }
      }
      .padding(16)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bg)
    .sheet(item: $editing) { target in
      SetEntrySheet(
        rowIndex: target.rowIndex,
        draft: target.draft,
        viewModel: viewModel,
        studentID: studentID,
        videoViewModel: videoViewModel,
        scrollToVideo: target.scrollToVideo
      )
    }
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
    draft: TodayWorkoutViewModel.SetRowDraft, rowIndex: Int, totalSets: Int, isEditable: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Eyebrow(
        "第 \(twoDigit(draft.prescribed.setIndex + 1)) / \(twoDigit(totalSets)) 组")

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
        recordActions(draft: draft, rowIndex: rowIndex)
          .padding(.top, 16)
      }
    }
    .padding(16)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  private func recordActions(
    draft: TodayWorkoutViewModel.SetRowDraft, rowIndex: Int
  ) -> some View {
    HStack(spacing: 8) {
      Button {
        editing = EditingTarget(
          id: draft.id, rowIndex: rowIndex, draft: draft, scrollToVideo: false)
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
        editing = EditingTarget(
          id: draft.id, rowIndex: rowIndex, draft: draft, scrollToVideo: true)
      } label: {
        Image(systemName: "video")
          .font(.system(size: 20))
          .foregroundStyle(Color.MeetPR.fgPrimary)
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

        ForEach(rows) { draft in
          let index = allDrafts.firstIndex { $0.id == draft.id } ?? 0
          setRow(
            draft: draft, rowIndex: index, active: activeIndex == index, isEditable: isEditable)
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
    draft: TodayWorkoutViewModel.SetRowDraft, rowIndex: Int, active: Bool, isEditable: Bool
  ) -> some View {
    if isEditable {
      Button {
        editing = EditingTarget(
          id: draft.id, rowIndex: rowIndex, draft: draft, scrollToVideo: false)
      } label: {
        setRowGrid(draft: draft, active: active)
      }
      .buttonStyle(.plain)
    } else {
      setRowGrid(draft: draft, active: active)
    }
  }

  private func setRowGrid(
    draft: TodayWorkoutViewModel.SetRowDraft, active: Bool
  ) -> some View {
    let resolved = draft.completed || active
    let foreground: Color = resolved ? Color.MeetPR.fgPrimary : Color.MeetPR.fgTertiary
    return LazyVGrid(columns: columns, spacing: 0) {
      Text("\(draft.prescribed.setIndex + 1)")
        .foregroundStyle(active ? Color.MeetPR.brandRed : Color.MeetPR.fgTertiary)
      Text(weightText(draft)).fontWeight(active ? .bold : .regular).foregroundStyle(foreground)
      Text(repsText(draft)).foregroundStyle(foreground)
      Text(rpeText(draft)).foregroundStyle(foreground)
      Text(statusMark(draft)).foregroundStyle(statusColor(draft))
      Image(systemName: "video")
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .frame(maxWidth: .infinity, alignment: .trailing)
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
    guard let day = currentDay else { return "锻炼" }
    let dayNumber = mondayOffset(day.date) + 1
    let weekday = viewModel.planContext.map { "W\($0.weekIndex)D\(dayNumber)" } ?? "今日"
    guard let lift = mainLift(day)?.studentDisplayName else { return weekday }
    return "\(weekday) · \(lift)"
  }

  private var currentDay: StudentPlanDay? {
    switch viewModel.state {
    case .loaded(let day, _): return day
    case .recording(let day, _, _): return day
    default: return nil
    }
  }

  private func mainLift(_ day: StudentPlanDay) -> LiftFamily? {
    day.exercises.first {
      $0.exercise.exerciseType == .mainLift && $0.exercise.mainLiftFamily != nil
    }?.exercise.mainLiftFamily
  }

  private func mondayOffset(_ date: Date) -> Int {
    let weekday = Calendar.current.component(.weekday, from: date)  // 1=Sun…7=Sat
    return (weekday + 5) % 7
  }

  private func totalSets(
    for planExerciseID: UUID, in drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> Int {
    drafts.filter { $0.planExerciseID == planExerciseID }.count
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
    await presentReadinessIfNeeded(for: date)
  }

  private func presentReadinessIfNeeded(for date: Date) async {
    guard Calendar.current.isDateInToday(date),
      case .loaded(_, let drafts) = viewModel.state,
      !drafts.isEmpty
    else { return }
    await readinessViewModel.load(studentId: studentID)
    if readinessViewModel.gate == .needed {
      showingReadinessSheet = true
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EditingTarget: Identifiable {
  let id: UUID
  let rowIndex: Int
  let draft: TodayWorkoutViewModel.SetRowDraft
  let scrollToVideo: Bool
}
// swiftlint:enable file_length type_body_length function_body_length
