import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TrainingHistoryView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  @State private var viewModel: TrainingHistoryViewModel
  @State private var selectedTab: TrainingHistoryTab = .progress
  @State private var selectedExerciseName: String?

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self._viewModel = State(initialValue: TrainingHistoryViewModel(plans: plans, logs: logs))
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Picker("历史视图", selection: $selectedTab) {
          Text("进度").tag(TrainingHistoryTab.progress)
          Text("历史").tag(TrainingHistoryTab.history)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.top, MeetPRSpacing.md)
        .padding(.bottom, MeetPRSpacing.sm)

        content()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .navigationTitle("进度")
    }
    .task {
      if viewModel.state == .idle {
        await viewModel.load(studentID: studentID)
      }
    }
  }

  @ViewBuilder
  private func content() -> some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .loaded(let weeks, let logs):
      if selectedTab == .progress {
        ProgressDashboardView(studentID: studentID, plans: plans, e1rm: e1rm, logs: logs)
      } else {
        HistoryEntriesView(
          weeks: weeks,
          logs: logs,
          selectedExerciseName: $selectedExerciseName
        )
      }
    case .error(let message):
      ContentUnavailableView(
        "加载失败",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
    }
  }
}

private enum TrainingHistoryTab: Hashable {
  case progress
  case history
}
