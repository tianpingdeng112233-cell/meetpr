import DesignSystem
import Networking
import SwiftUI

/// At accessibility sizes, keep each metric readable instead of truncating a dense table row.
@MainActor
struct CoachSetReadOnlyRow: View {
  let log: CoachSetLogDTO
  let isAccessibilitySize: Bool

  var body: some View {
    if isAccessibilitySize {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        HStack {
          Text("#\(log.setIndex + 1)")
            .font(Font.MeetPR.monoLabel)
          Spacer()
          Image(systemName: log.completed ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(log.completed ? Color.MeetPR.green : Color.MeetPR.fgTertiary)
        }
        LabeledContent(CoachLocalization.localized("coach.videoFeedback.weight")) {
          Text("\(log.weightKg.formatted(.number.precision(.fractionLength(0...2)))) kg")
        }
        LabeledContent(CoachLocalization.localized("coach.videoFeedback.reps")) {
          Text(log.reps.formatted())
        }
        LabeledContent(
          log.actualRIR != nil ? "RIR" : CoachLocalization.localized("coach.videoFeedback.rpe")
        ) {
          Text(
            log.actualRIR.map { String($0) } ?? log.rpe?.formatted(
              .number.precision(.fractionLength(0...2))) ?? "–")
        }
      }
      .font(Font.MeetPR.bodyEmphasis)
      .foregroundStyle(Color.MeetPR.fgPrimary)
      .padding(MeetPRSpacing.sm)
      .background(Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      .accessibilityElement(children: .combine)
    } else {
      SetReadOnlyCell(
        setIndex: log.setIndex, weightKg: log.weightKg, reps: log.reps,
        rpe: log.rpe, isCompleted: log.completed)
    }
  }
}
