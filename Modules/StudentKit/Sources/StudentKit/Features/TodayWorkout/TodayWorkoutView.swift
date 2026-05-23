import CoreModels
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TodayWorkoutView: View {
  private let studentID: UUID
  private let date: Date
  @State private var viewModel: TodayWorkoutViewModel

  public init(
    studentID: UUID,
    date: Date = Date(),
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository
  ) {
    self.studentID = studentID
    self.date = date
    self._viewModel = State(initialValue: TodayWorkoutViewModel(plans: plans, logs: logs))
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
          ContentUnavailableView("今天休息", systemImage: "bed.double", description: Text("看本周计划"))
        case .error(let message):
          ContentUnavailableView(
            "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
        }
      }
      .navigationTitle("今天")
      .toolbar {
        Button {
          Task { await viewModel.load(date: date, studentID: studentID) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .accessibilityLabel("刷新")
      }
    }
    .task {
      if viewModel.state == .idle {
        await viewModel.load(date: date, studentID: studentID)
      }
    }
  }

  private func workout(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        let weekday = StudentFormatting.weekdayFormatter.string(from: day.date)
        Text("Week \(weekLabel(for: day.date)) · \(weekday)")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        ForEach(day.exercises) { exercise in
          ExerciseExecutionView(
            exercise: exercise,
            rows: rows(for: exercise, drafts: drafts),
            rowIndex: { draft in drafts.firstIndex(where: { $0.id == draft.id }) },
            viewModel: viewModel
          )
        }

        if !drafts.isEmpty && drafts.allSatisfy(\.completed) {
          DayCompletionBanner(totalSets: drafts.count)
        }
      }
      .padding()
    }
  }

  private func rows(
    for exercise: StudentPlanExercise,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> [TodayWorkoutViewModel.SetRowDraft] {
    drafts.filter { $0.planExerciseID == exercise.id }
  }

  private func weekLabel(for date: Date) -> Int {
    Calendar.current.component(.weekOfYear, from: date)
  }
}
