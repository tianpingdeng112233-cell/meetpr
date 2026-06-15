import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ExerciseExecutionView: View {
  let exercise: StudentPlanExercise
  let rows: [TodayWorkoutViewModel.SetRowDraft]
  let reference: ExerciseReference?
  let rowIndex: (TodayWorkoutViewModel.SetRowDraft) -> Int?
  let onTapSet: (Int) -> Void
  var onPlateMath: ((Double) -> Void)?

  private var allCompleted: Bool {
    !rows.isEmpty && rows.allSatisfy(\.completed)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.exercise.name)
            .font(.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(prescriptionSummary)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          if let reference, reference.hasValue {
            ExerciseReferenceRow(reference: reference)
          }
        }
        Spacer()
        Image(systemName: allCompleted ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(allCompleted ? Color.MeetPR.green : Color.MeetPR.fgTertiary)
      }

      ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
        if let index = rowIndex(row) {
          SetRecordRow(
            draft: row, setNumber: offset + 1, rowIndex: index,
            onTap: onTapSet, onPlateMath: onPlateMath)
        }
      }
    }
    .padding(14)
    .background(Color.MeetPR.surface1)
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Color.MeetPR.brandRed)
        .frame(width: 3)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 14))
  }

  private var prescriptionSummary: String {
    guard let first = rows.first?.prescribed else { return "\(rows.count) 组" }
    let reps = first.reps.map(String.init) ?? first.repsMax.map { "≤\($0)" } ?? "—"
    var summary = "\(rows.count) 组 × \(reps) 次"
    if let rpe = first.rpe {
      summary += " @ RPE\(StudentFormatting.decimal(rpe))"
    }
    return summary
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ExerciseReferenceRow: View {
  let reference: ExerciseReference

  var body: some View {
    Text(parts.joined(separator: " · "))
      .font(.caption)
      .foregroundStyle(Color.MeetPR.fgTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var parts: [String] {
    [
      reference.last.map { "上次 \(Self.format($0))" },
      reference.best.map { "最佳 \(Self.format($0))" },
    ].compactMap(\.self)
  }

  private static func format(_ set: ExerciseReferenceSet) -> String {
    "\(set.reps)×\(StudentFormatting.kilograms(set.weightKg))kg"
  }
}
