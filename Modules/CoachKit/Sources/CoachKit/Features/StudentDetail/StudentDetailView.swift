import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentDetailView: View {
  @Bindable private var viewModel: StudentDetailViewModel
  @State private var videoGridViewModel: StudentVideoGridViewModel
  @State private var growthViewModel: StudentGrowthViewModel
  private let feedback: any StudentFeedbackRepository
  @State private var showComposer = false

  init(
    summary: CoachStudentSummary,
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    videos: any CoachStudentVideoRepository,
    readiness: any ReadinessRepository,
    familyMapProvider: (any CoachPlanFamilyMapProviding)? = nil
  ) {
    viewModel = StudentDetailViewModel(
      summary: summary,
      plans: plans,
      trainingLogs: trainingLogs,
      feedback: feedback,
      videos: videos,
      readiness: readiness
    )
    _videoGridViewModel = State(initialValue: StudentVideoGridViewModel(repository: videos))
    _growthViewModel = State(
      initialValue: StudentGrowthViewModel(
        plans: plans, trainingLogs: trainingLogs, familyMapProvider: familyMapProvider)
    )
    self.feedback = feedback
  }

  var body: some View {
    VStack(spacing: 0) {
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
        repository: feedback
      ) { item in
        viewModel.appendPostedFeedback(item)
      }
    }
    .task {
      await viewModel.loadIfNeeded()
    }
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
        videosUnavailable: viewModel.videosUnavailable
      ) { section in
        viewModel.select(section)
      }
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
