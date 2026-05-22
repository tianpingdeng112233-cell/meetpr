import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TrainingHistoryView: View {
  private let studentID: UUID
  @State private var viewModel: TrainingHistoryViewModel

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository
  ) {
    self.studentID = studentID
    self._viewModel = State(initialValue: TrainingHistoryViewModel(plans: plans, logs: logs))
  }

  public var body: some View {
    NavigationStack {
      Group {
        switch viewModel.state {
        case .idle, .loading:
          ProgressView()
        case .loaded(let weeks, let logs):
          List {
            Picker("视图", selection: .constant("week")) {
              Text("按周").tag("week")
              Text("按月").tag("month")
            }
            .pickerStyle(.segmented)
            .disabled(true)

            ForEach(weeks) { week in
              Section("Week \(week.id)") {
                ForEach(week.days) { day in
                  NavigationLink {
                    DayDetailView(day: day, logs: logs)
                  } label: {
                    DayCard(day: day, logs: logs)
                  }
                }
              }
            }
          }
        case .error(let message):
          ContentUnavailableView(
            "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
        }
      }
      .navigationTitle("历史")
    }
    .task {
      if viewModel.state == .idle {
        await viewModel.load(studentID: studentID)
      }
    }
  }
}
