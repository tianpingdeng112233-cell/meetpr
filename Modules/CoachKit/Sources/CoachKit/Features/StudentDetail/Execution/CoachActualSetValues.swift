import CoreModels
import DesignSystem
import Networking
import SwiftUI

struct CoachActualSetValues: View {
  let log: CoachSetLogDTO
  let prescribed: PrescribedSet?
  var isAccessibilitySize = false

  private var originalWeight: String? {
    guard let prescribed else { return nil }
    if case .weightRange(let low, let high) = prescribed.intensity {
      if let weight = log.weightKg, (low...high).contains(weight) { return nil }
      return "\(low.formatted())–\(high.formatted())"
    }
    return prescribed.weightKg == log.weightKg ? nil : prescribed.weightKg?.formatted() ?? "—"
  }

  private var originalEffort: String? {
    guard let prescribed else { return nil }
    switch prescribed.intensity {
    case .rir(let target):
      return log.actualRIR == target && log.rpe == nil ? nil : "RIR \(target)"
    case .rpeRange(let low, let high):
      if let rpe = log.rpe, log.actualRIR == nil, (low...high).contains(rpe) { return nil }
      return "RPE \(low.formatted())–\(high.formatted())"
    default:
      return log.rpe == prescribed.rpe && log.actualRIR == nil
        ? nil : prescribed.rpe.map { "RPE \($0.formatted())" } ?? "—"
    }
  }

  var body: some View {
    let layout =
      isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: MeetPRSpacing.space3))
      : AnyLayout(HStackLayout(spacing: MeetPRSpacing.space3))
    layout {
      Text("#\(log.setIndex + 1)").font(Font.MeetPR.monoLabel)
      CoachSetMetric(
        actual: log.weightKg.map { "\($0.formatted()) kg" } ?? "—",
        original: originalWeight)
      CoachSetMetric(
        actual: String(log.reps),
        original: prescribed.flatMap { set in
          guard let reps = set.reps, !(reps...(set.repsMax ?? reps)).contains(log.reps) else {
            return nil
          }
          return set.repsMax.map { "\(reps)–\($0)" } ?? String(reps)
        })
      if !isAccessibilitySize { Spacer(minLength: 0) }
      CoachSetMetric(
        actual: log.actualRIR.map { "RIR \($0)" } ?? log.rpe.map { "RPE \($0.formatted())" } ?? "—",
        original: originalEffort)
      Image(systemName: log.completed ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(log.completed ? Color.MeetPR.success : Color.MeetPR.textSecondary)
    }
    .font(Font.MeetPR.bodyEmphasis)
    .padding(MeetPRSpacing.sm)
    .background(Color.MeetPR.surface2, in: .rect(cornerRadius: MeetPRRadius.md))
  }
}

private struct CoachSetMetric: View {
  let actual: String
  let original: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(actual).foregroundStyle(
        original == nil ? Color.MeetPR.textPrimary : Color.MeetPR.goldText)
      if let original {
        Text(CoachLocalization.localized("coach.execution.original") + " " + original)
          .font(.caption2).foregroundStyle(Color.MeetPR.textSecondary)
      }
    }
  }
}
