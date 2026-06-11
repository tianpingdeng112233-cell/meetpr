import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentDetailView: View {
  @Bindable private var viewModel: StudentDetailViewModel
  @State private var videoGridViewModel: StudentVideoGridViewModel
  @State private var growthViewModel: StudentGrowthViewModel
  @State private var evaluationViewModel: EvaluationBannerViewModel
  private let context: CoachStudentDetailContext
  @State private var showComposer = false
  @State private var showSummaryEditor = false
  @State private var showAdaptationPlanning = false

  init(
    summary: CoachStudentSummary,
    context: CoachStudentDetailContext,
    onEvaluationCompleted: (@MainActor () -> Void)? = nil
  ) {
    viewModel = StudentDetailViewModel(
      summary: summary,
      plans: context.plans,
      trainingLogs: context.trainingLogs,
      feedback: context.feedback,
      videos: context.videos,
      readiness: context.readiness
    )
    _videoGridViewModel = State(
      initialValue: StudentVideoGridViewModel(repository: context.videos)
    )
    _growthViewModel = State(
      initialValue: StudentGrowthViewModel(
        plans: context.plans,
        trainingLogs: context.trainingLogs,
        familyMapProvider: context.familyMapProvider
      )
    )
    _evaluationViewModel = State(
      initialValue: EvaluationBannerViewModel(
        studentID: summary.id,
        evaluations: context.evaluations,
        summaries: context.summaries,
        onCompleted: onEvaluationCompleted
      )
    )
    self.context = context
  }

  var body: some View {
    VStack(spacing: 0) {
      if evaluationViewModel.loadFailed {
        EvaluationLoadFailureStrip {
          Task { await evaluationViewModel.load() }
        }
        .padding(.horizontal, MeetPRSpacing.base)
        .padding(.top, MeetPRSpacing.sm)
      } else if evaluationViewModel.isBannerVisible {
        EvaluationStatusBanner(
          viewModel: evaluationViewModel,
          hasPublishedPlan: viewModel.plan != nil,
          onSendAdaptationWeek: { showAdaptationPlanning = true },
          onViewAdaptationWeek: { viewModel.select(.execution) },
          onOpenSummary: { showSummaryEditor = true }
        )
        .padding(.horizontal, MeetPRSpacing.base)
        .padding(.top, MeetPRSpacing.sm)
      }

      Picker("", selection: $viewModel.selectedSection) {
        ForEach(StudentDetailSection.allCases) { section in
          Text(section.title).tag(section)
        }
      }
      .pickerStyle(.segmented)
      .padding(MeetPRSpacing.base)

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Spec 029 §risk 5: auto fetch once on appear + pull-to-refresh as
        // the explicit retry path (the "下拉刷新重试" copy in the video wall
        // and readiness row points here). Growth keeps its own cache, so the
        // pull refreshes whichever data the visible section reads.
        .refreshable { [viewModel, growthViewModel] in
          if await viewModel.selectedSection == .growth {
            await growthViewModel.load(studentID: viewModel.summary.id)
          } else {
            await viewModel.refresh()
          }
        }
    }
    .navigationTitle(viewModel.summary.displayName)
    .background(Color.MeetPR.bg)
    .toolbar {
      if viewModel.selectedSection == .feedback {
        ToolbarItem(placement: .primaryAction) {
          Button {
            showComposer = true
          } label: {
            Image(systemName: "square.and.pencil")
          }
          .accessibilityLabel("写反馈")
        }
      }
    }
    .sheet(isPresented: $showComposer) {
      FeedbackComposerView(
        studentID: viewModel.summary.id,
        studentName: viewModel.summary.displayName,
        days: viewModel.plannedDays,
        repository: context.feedback
      ) { item in
        viewModel.appendPostedFeedback(item)
      }
    }
    .navigationDestination(isPresented: $showSummaryEditor) {
      summaryEditor
    }
    .onChange(of: showSummaryEditor) { _, isShowing in
      if !isShowing {
        // Returning from the editor: refresh the overview summary card.
        Task { await evaluationViewModel.reloadSummary() }
      }
    }
    .modifier(
      AdaptationPlanningPresenter(
        isPresented: $showAdaptationPlanning,
        student: viewModel.summary,
        context: context
      )
    )
    .task {
      await viewModel.loadIfNeeded()
      await evaluationViewModel.load()
    }
  }

  private var summaryEditor: some View {
    EvaluationSummaryEditorView(
      viewModel: EvaluationSummaryEditorViewModel(
        student: viewModel.summary,
        evaluation: evaluationViewModel.evaluation,
        summaries: context.summaries,
        evaluations: context.evaluations,
        profiles: context.profiles,
        onEvaluationCompleted: { completed in
          evaluationViewModel.markEvaluationCompleted(completed)
        }
      ),
      context: context
    )
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
    case .failed(let message):
      ContentUnavailableView(
        "加载失败",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
    case .loaded:
      sectionContent
    }
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch viewModel.selectedSection {
    case .overview:
      StudentOverviewSection(
        summary: viewModel.overview,
        readiness: viewModel.todayReadiness,
        recentVideos: viewModel.recentVideos,
        videosUnavailable: viewModel.videosUnavailable,
        evaluationSummary: evaluationViewModel.summary,
        onSelectSection: { section in
          viewModel.select(section)
        },
        onOpenEvaluationSummary: {
          showSummaryEditor = true
        }
      )
    case .execution:
      StudentExecutionView(days: viewModel.executionDays)
    case .videos:
      StudentVideoGridView(
        videos: viewModel.videos,
        unavailable: viewModel.videosUnavailable,
        viewModel: videoGridViewModel
      )
    case .growth:
      StudentGrowthView(studentID: viewModel.summary.id, viewModel: growthViewModel)
    case .feedback:
      CoachFeedbackHistoryView(
        feedback: viewModel.feedbackItems,
        days: viewModel.plannedDays,
        onCompose: {
          showComposer = true
        }
      )
    }
  }
}

/// Transport-failure fallback for the evaluation strip (Codex review P2):
/// without it a network blip silently hides a live evaluation banner and the
/// page reads as "no evaluation".
@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct EvaluationLoadFailureStrip: View {
  let onRetry: () -> Void

  var body: some View {
    Card(accessibilityLabel: "评估状态加载失败") {
      HStack(spacing: MeetPRSpacing.sm) {
        Text("评估状态加载失败")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Spacer()
        SecondaryButton("重试") {
          onRetry()
        }
      }
    }
  }
}

/// fullScreenCover on iOS / sheet on macOS for the adaptation-week planning
/// entry (spec 033 §7).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct AdaptationPlanningPresenter: ViewModifier {
  @Binding var isPresented: Bool
  let student: CoachStudentSummary
  let context: CoachStudentDetailContext

  func body(content: Content) -> some View {
    #if os(iOS)
      content.fullScreenCover(isPresented: $isPresented) {
        planning
      }
    #else
      content.sheet(isPresented: $isPresented) {
        planning
      }
    #endif
  }

  private var planning: some View {
    PlanningCoordinatorView(
      repository: context.planning,
      draftStore: context.draftStore,
      intent: .adaptationWeek(student)
    )
  }
}
