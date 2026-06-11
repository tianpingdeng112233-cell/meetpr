import CoreModels
import DesignSystem
import SwiftUI

/// One set, Juggernaut-style: [number] [target weight] … [result pill].
/// The whole row is a button that opens `SetEntrySheet`; a completed set shows
/// its logged result as a filled accent pill with a check.
@available(iOS 17.0, macOS 14.0, *)
struct SetRecordRow: View {
  let draft: TodayWorkoutViewModel.SetRowDraft
  let rowIndex: Int
  let onTap: (Int) -> Void

  private var resultText: String {
    let weight = StudentFormatting.decimal(draft.actualWeight ?? draft.prescribed.weightKg)
    let reps = draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0
    let rpe = StudentFormatting.decimal(draft.actualRPE ?? draft.prescribed.rpe)
    return "\(weight) × \(reps) @ \(rpe)"
  }

  private var targetWeight: String? {
    draft.prescribed.weightKg.map { "\(StudentFormatting.decimal($0)) kg" }
  }

  var body: some View {
    Button {
      onTap(rowIndex)
    } label: {
      HStack(spacing: 12) {
        Text("\(draft.prescribed.setIndex + 1)")
          .font(.subheadline.monospacedDigit().bold())
          .foregroundStyle(draft.completed ? .white : Color.MeetPR.fgSecondary)
          .frame(width: 30, height: 30)
          .background(draft.completed ? Color.MeetPR.green : Color.MeetPR.surface2)
          .clipShape(Circle())

        if let targetWeight {
          Text(targetWeight)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }

        Spacer()

        HStack(spacing: 6) {
          Text(resultText)
            .font(.subheadline.monospacedDigit().bold())
          Image(systemName: draft.completed ? "checkmark" : "pencil")
            .font(.caption2.bold())
        }
        .foregroundStyle(draft.completed ? Color.MeetPR.green : Color.MeetPR.fgSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(draft.completed ? Color.MeetPR.greenSoft : Color.MeetPR.surface2)
        .clipShape(.capsule)
      }
    }
    .buttonStyle(.plain)
  }
}
