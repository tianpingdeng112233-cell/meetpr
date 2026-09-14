import DesignSystem
import SwiftUI

/// Shared destination for Growth and Training. Navigation does not recreate or
/// mutate the active workout, its draft, or its rest timer.
@available(iOS 17.0, macOS 14.0, *)
struct AllHistoryScreen: View {
  let viewModel: TrainingHistoryViewModel
  let studentID: UUID
  @State private var selectedExerciseName: String?

  var body: some View {
    Group {
      switch viewModel.state {
      case .loaded(let weeks, let logs):
        if logs.isEmpty {
          ContentUnavailableView(
            StudentStrings.localized(.e1rmSourceHistoryEmpty), systemImage: "clock",
            description: Text(StudentStrings.localized(.e1rmSourceHistoryEmptyNote))
          )
        } else {
          HistoryEntriesView(weeks: weeks, logs: logs, selectedExerciseName: $selectedExerciseName)
        }
      case .error(let message):
        VStack(spacing: MeetPRSpacing.space3) {
          ContentUnavailableView(
            StudentStrings.localized(.trainingHistoryView022),
            systemImage: "exclamationmark.triangle", description: Text(message)
          )
          Button(StudentStrings.localized(.trainingHistoryView023)) {
            Task { await viewModel.load(studentID: studentID) }
          }
          .foregroundStyle(Color.MeetPR.goldText)
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
        }
      case .idle, .loading:
        ProgressView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .navigationTitle(StudentStrings.localized(.trainingHistoryView024))
    #if os(iOS)
      .toolbar(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .task {
      await viewModel.load(studentID: studentID)
    }
  }
}
