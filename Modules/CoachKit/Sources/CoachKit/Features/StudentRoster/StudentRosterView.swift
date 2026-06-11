import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterView: View {
  @Bindable private var viewModel: StudentRosterViewModel
  private let plans: any StudentPlanRepository
  private let trainingLogs: any StudentTrainingLogRepository
  private let feedback: any StudentFeedbackRepository

  init(
    viewModel: StudentRosterViewModel,
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository
  ) {
    self.viewModel = viewModel
    self.plans = plans
    self.trainingLogs = trainingLogs
    self.feedback = feedback
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("学员")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              Task {
                await viewModel.refresh()
              }
            } label: {
              Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("刷新学员")
          }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.MeetPR.bg)
    case .failed(let message):
      ContentUnavailableView(
        "加载失败",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
      .background(Color.MeetPR.bg)
    case .loaded:
      if viewModel.rows.isEmpty {
        ContentUnavailableView(
          "暂无学员",
          systemImage: "person.2",
          description: Text("等邀请码 V0.1.x")
        )
        .background(Color.MeetPR.bg)
      } else {
        List {
          ForEach(viewModel.filteredRows) { row in
            NavigationLink {
              StudentDetailView(
                summary: row.student,
                plans: plans,
                trainingLogs: trainingLogs,
                feedback: feedback
              )
            } label: {
              StudentRosterRow(row: row)
            }
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.MeetPR.bg)
        .refreshable {
          await viewModel.refresh()
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索学员")
      }
    }
  }
}
