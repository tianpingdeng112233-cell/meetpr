import CoreModels
import DesignSystem
import SwiftUI

/// One set, Juggernaut-style: [number] [target weight] [⚖] … [result pill].
/// Two side-by-side buttons (spec 030 §A2): the row body opens
/// `SetEntrySheet`; the scalemass icon next to the target weight opens the
/// plate-math sheet. Never nest the icon inside the row button — gestures
/// fight.
@available(iOS 17.0, macOS 14.0, *)
struct SetRecordRow: View {
  let draft: TodayWorkoutViewModel.SetRowDraft
  let rowIndex: Int
  let onTap: (Int) -> Void
  var onPlateMath: ((Double) -> Void)?

  private var resultText: String {
    let weight = StudentFormatting.decimal(draft.actualWeight ?? draft.prescribed.weightKg)
    let reps = draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0
    let rpe = StudentFormatting.decimal(draft.actualRPE ?? draft.prescribed.rpe)
    return "\(weight) × \(reps) @ \(rpe)"
  }

  private var targetWeight: String? {
    draft.prescribed.weightKg.map { "\(StudentFormatting.decimal($0)) kg" }
  }

  private var plateMathWeightKg: Double? {
    (draft.actualWeight ?? draft.prescribed.weightKg)
      .map { NSDecimalNumber(decimal: $0).doubleValue }
  }

  var body: some View {
    HStack(spacing: 12) {
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
        }
      }
      .buttonStyle(.plain)

      if let onPlateMath, let weight = plateMathWeightKg {
        Button {
          onPlateMath(weight)
        } label: {
          Image(systemName: "scalemass")
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("配片计算")
      }

      Button {
        onTap(rowIndex)
      } label: {
        HStack(spacing: 6) {
          Spacer(minLength: 0)
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
}
