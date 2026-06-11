import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentDetailView: View {
  @Bindable private var viewModel: StudentDetailViewModel
  private let feedback: any StudentFeedbackRepository
  @State private var showComposer = false

  init(
    summary: CoachStudentSummary,
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository
  ) {
    viewModel = StudentDetailViewModel(
      summary: summary,
      plans: plans,
      trainingLogs: trainingLogs,
      feedback: feedback
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
      StudentOverviewSection(summary: viewModel.overview) { section in
        viewModel.select(section)
      }
    case .execution:
      StudentExecutionView(days: viewModel.executionDays)
    case .videos:
      DeferredStudentSection(title: "即将上线", subtitle: "待 027", systemImage: "video")
    case .growth:
      DeferredStudentSection(
        title: "即将上线", subtitle: "待 028", systemImage: "chart.line.uptrend.xyaxis")
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

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct DeferredStudentSection: View {
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    ContentUnavailableView(title, systemImage: systemImage, description: Text(subtitle))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
  }
}
