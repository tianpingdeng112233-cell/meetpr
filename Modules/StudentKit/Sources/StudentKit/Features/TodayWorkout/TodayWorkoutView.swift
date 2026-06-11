import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TodayWorkoutView: View {
  private let studentID: UUID
  private let date: Date
  @State private var viewModel: TodayWorkoutViewModel
  @State private var showingSummary = false
  @State private var editing: EditingTarget?

  public init(
    studentID: UUID,
    date: Date = Date(),
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository()
  ) {
    self.studentID = studentID
    self.date = date
    self._viewModel = State(
      initialValue: TodayWorkoutViewModel(plans: plans, logs: logs, e1rm: e1rm))
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
    .task {
      if viewModel.state == .idle {
        await viewModel.load(date: date, studentID: studentID)
        // Re-surface a PR banner the student never dismissed (spec 028 §5);
        // delayed so the tab renders first.
        try? await Task.sleep(for: .seconds(1.5))
        await viewModel.surfaceUnacknowledgedPR(studentID: studentID)
      }
    }
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
      SetEntrySheet(rowIndex: target.rowIndex, draft: target.draft, viewModel: viewModel)
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
