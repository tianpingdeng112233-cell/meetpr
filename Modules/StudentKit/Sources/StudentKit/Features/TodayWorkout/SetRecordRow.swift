import CoreModels
import DesignSystem
import SwiftUI

enum SetRecordResultState: Equatable, Sendable {
  case completed
  case failed
  case unlogged

  static func resolve(for draft: TodayWorkoutViewModel.SetRowDraft) -> SetRecordResultState {
    guard draft.completed else { return .unlogged }
    return draft.failed ? .failed : .completed
  }

  var iconName: String {
    switch self {
    case .completed:
      "checkmark"
    case .failed:
      "xmark"
    case .unlogged:
      "pencil"
    }
  }

  var accentColor: Color {
    switch self {
    case .completed:
      Color.MeetPR.green
    case .failed:
      Color.MeetPR.amber
    case .unlogged:
      Color.MeetPR.fgSecondary
    }
  }

  var softBackgroundColor: Color {
    switch self {
    case .completed:
      Color.MeetPR.greenSoft
    case .failed:
      Color.MeetPR.amberSoft
    case .unlogged:
      Color.MeetPR.surface2
    }
  }

  var numberBackgroundColor: Color {
    switch self {
    case .completed:
      Color.MeetPR.green
    case .failed:
      Color.MeetPR.amber
    case .unlogged:
      Color.MeetPR.surface2
    }
  }

  var numberForegroundColor: Color {
    self == .unlogged ? Color.MeetPR.fgSecondary : .white
  }
}

/// One set, Juggernaut-style: [number] [target weight] [⚖] … [result pill].
/// Two side-by-side buttons (spec 030 §A2): the row body opens
/// `SetEntrySheet`; the scalemass icon next to the target weight opens the
/// plate-math sheet. Never nest the icon inside the row button — gestures
/// fight.
@available(iOS 17.0, macOS 14.0, *)
struct SetRecordRow: View {
  let draft: TodayWorkoutViewModel.SetRowDraft
  /// 1-based position within the exercise. Decoupled from the stored setIndex,
  /// which is 0-based in demo seeds but 1-based from the backend — deriving the
  /// label from setIndex showed real plans as 2,3,4,5 instead of 1,2,3,4.
  let setNumber: Int
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

  private var resultState: SetRecordResultState {
    SetRecordResultState.resolve(for: draft)
  }

  var body: some View {
    HStack(spacing: 12) {
      Button {
        onTap(rowIndex)
      } label: {
        HStack(spacing: 12) {
          Text("\(setNumber)")
            .font(.subheadline.monospacedDigit().bold())
            .foregroundStyle(resultState.numberForegroundColor)
            .frame(width: 30, height: 30)
            .background(resultState.numberBackgroundColor)
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
            Image(systemName: resultState.iconName)
              .font(.caption2.bold())
          }
          .foregroundStyle(resultState.accentColor)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(resultState.softBackgroundColor)
          .clipShape(.capsule)
          .overlay {
            if resultState == .unlogged {
              Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
            }
          }
        }
      }
      .buttonStyle(.plain)
    }
  }
}
