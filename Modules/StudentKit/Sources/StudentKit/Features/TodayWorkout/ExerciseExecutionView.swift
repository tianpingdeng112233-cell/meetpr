import CoreModels
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ExerciseExecutionView: View {
  let exercise: StudentPlanExercise
  let rows: [TodayWorkoutViewModel.SetRowDraft]
  let rowIndex: (TodayWorkoutViewModel.SetRowDraft) -> Int?
  let viewModel: TodayWorkoutViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.exercise.name)
            .font(.headline)
          Text("\(rows.count) 组")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: rows.allSatisfy(\.completed) ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(rows.allSatisfy(\.completed) ? .green : .secondary)
      }

      ForEach(rows) { row in
        if let index = rowIndex(row) {
          SetRecordRow(draft: row, rowIndex: index, viewModel: viewModel)
        }
      }
    }
    .padding()
    .background(.background)
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(.quaternary, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 8))
  }
}
