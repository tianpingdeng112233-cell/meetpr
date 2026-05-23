import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct SetRecordRow: View {
  let draft: TodayWorkoutViewModel.SetRowDraft
  let rowIndex: Int
  let viewModel: TodayWorkoutViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Text("\(draft.prescribed.setIndex + 1)")
          .font(.headline.monospacedDigit())
          .frame(width: 28, height: 28)
          .background(.quaternary)
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text(StudentFormatting.prescribed(draft.prescribed))
            .font(.subheadline.monospacedDigit())
          Text(draft.exerciseName)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button {
          Task { await viewModel.toggleComplete(rowIndex: rowIndex) }
        } label: {
          Image(systemName: draft.completed ? "checkmark.circle.fill" : "checkmark.circle")
            .font(.title3)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(draft.completed ? .green : .primary)
        .accessibilityLabel(draft.completed ? "取消完成" : "完成")
      }

      HStack {
        TextField(
          "次数",
          value: Binding(
            get: { draft.actualReps },
            set: { viewModel.updateReps(rowIndex: rowIndex, reps: $0) }
          ),
          format: .number
        )
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 96)

        Stepper(
          "RPE \(StudentFormatting.decimal(draft.actualRPE))",
          value: Binding(
            get: { NSDecimalNumber(decimal: draft.actualRPE ?? 8).doubleValue },
            set: { viewModel.updateRPE(rowIndex: rowIndex, rpe: Decimal($0)) }
          ),
          in: 5...10,
          step: 0.5
        )
        .font(.subheadline)
      }
    }
    .padding(12)
    .background(draft.completed ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
    .clipShape(.rect(cornerRadius: 8))
  }
}
