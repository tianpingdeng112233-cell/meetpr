import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TodayWorkoutView: View {
  private let studentID: UUID
  private let date: Date
  @State private var viewModel: TodayWorkoutViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var videoViewModel: VideoAttachmentViewModel
  @State private var showingSummary = false
  @State private var editing: EditingTarget?
  @State private var plateMathTarget: PlateMathTarget?
  @State private var showingReadinessSheet = false

  public init(
    studentID: UUID,
    date: Date = Date(),
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    videoUploads: VideoUploadServices? = nil
  ) {
    self.studentID = studentID
    self.date = date
    self._viewModel = State(
      initialValue: TodayWorkoutViewModel(plans: plans, logs: logs, e1rm: e1rm))
    self._readinessViewModel = State(
      initialValue: ReadinessCheckinViewModel(repo: readiness))
    self._videoViewModel = State(
      initialValue: VideoAttachmentViewModel(manager: (videoUploads ?? .demo()).manager))
  }

  public var body: some View {
    NavigationStack {
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
          ContentUnavailableView("今日休息", systemImage: "bed.double", description: Text("看本周计划"))
        case .error(let message):
          ContentUnavailableView(
            "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .navigationTitle("今天")
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
          Task { await viewModel.load(date: date, studentID: studentID) }
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
    .sheet(item: $plateMathTarget) { target in
      PlateMathSheet(targetKg: target.weightKg)
        .presentationDetents([.medium])
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
    .task {
      if viewModel.state == .idle {
        await viewModel.load(date: date, studentID: studentID)
        await videoViewModel.start(studentID: studentID)

        // Readiness gate (spec 030 §C4): auto-present at most once per day,
        // only for today's view, only when a non-empty workout loaded, only
        // while neither filed nor skipped. Rest days never prompt.
        if Calendar.current.isDateInToday(date),
          case .loaded(_, let drafts) = viewModel.state, !drafts.isEmpty
        {
          await readinessViewModel.load(studentId: studentID)
          if readinessViewModel.gate == .needed {
            showingReadinessSheet = true
          }
        }

        // Re-surface a PR banner the student never dismissed (spec 028 §5);
        // delayed so the tab renders first.
        try? await Task.sleep(for: .seconds(1.5))
        await viewModel.surfaceUnacknowledgedPR(studentID: studentID)
      }
    }
  }

  private var readinessFiled: Bool {
    if case .done = readinessViewModel.gate { return true }
    return false
  }

  private var readinessPrefill: ReadinessCheckin? {
    if case .done(let checkin) = readinessViewModel.gate { return checkin }
    return nil
  }

  private func workout(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        header(for: day)

        ForEach(day.exercises) { exercise in
          ExerciseExecutionView(
            exercise: exercise,
            rows: rows(for: exercise, drafts: drafts),
            rowIndex: { draft in drafts.firstIndex(where: { $0.id == draft.id }) },
            onTapSet: { index in
              if drafts.indices.contains(index) {
                editing = EditingTarget(
                  id: drafts[index].id, rowIndex: index, draft: drafts[index])
              }
            },
            onPlateMath: { weightKg in
              plateMathTarget = PlateMathTarget(weightKg: weightKg)
            }
          )
        }

        if !drafts.isEmpty && drafts.allSatisfy(\.completed) {
          DayCompletionBanner(totalSets: drafts.count)
        }

        SlideToCompleteButton(title: "滑动完成今日训练") {
          showingSummary = true
        }
        .padding(.top, 4)
        .sheet(isPresented: $showingSummary) {
          SessionSummaryView(summary: StudentSessionSummary(drafts: drafts), date: day.date)
        }
      }
      .padding()
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bg)
    .sheet(item: $editing) { target in
      SetEntrySheet(
        rowIndex: target.rowIndex,
        draft: target.draft,
        viewModel: viewModel,
        studentID: studentID,
        videoViewModel: videoViewModel
      )
    }
  }

  private func header(for day: StudentPlanDay) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(StudentFormatting.weekdayFormatter.string(from: day.date))
        .font(.title2.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text(StudentFormatting.dayMonthFormatter.string(from: day.date))
        .font(.subheadline)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func rows(
    for exercise: StudentPlanExercise,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> [TodayWorkoutViewModel.SetRowDraft] {
    drafts.filter { $0.planExerciseID == exercise.id }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EditingTarget: Identifiable {
  let id: UUID
  let rowIndex: Int
  let draft: TodayWorkoutViewModel.SetRowDraft
}

@available(iOS 17.0, macOS 14.0, *)
private struct PlateMathTarget: Identifiable {
  let weightKg: Double
  var id: Double { weightKg }
}
