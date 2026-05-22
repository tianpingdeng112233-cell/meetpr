import CoreModels
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct WeekOverviewView: View {
  private let studentID: UUID
  @State private var viewModel: WeekOverviewViewModel

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository
  ) {
    self.studentID = studentID
    self._viewModel = State(initialValue: WeekOverviewViewModel(plans: plans, logs: logs))
  }

  public var body: some View {
    NavigationStack {
      Group {
        switch viewModel.state {
        case .idle, .loading:
          ProgressView()
        case .loaded(let days, let logs, let weekIndex):
          List {
            Section("Week \(weekIndex)") {
              ForEach(days) { day in
                NavigationLink {
                  DayDetailView(day: day, logs: logs)
                } label: {
                  DayCard(day: day, logs: logs)
                }
              }
            }
          }
        case .error(let message):
          ContentUnavailableView(
            "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
        }
      }
      .navigationTitle("本周")
    }
    .task {
      if viewModel.state == .idle {
        await viewModel.load(studentID: studentID)
      }
    }
  }
}
