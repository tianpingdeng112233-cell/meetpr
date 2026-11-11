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
    if case .percentage(let value) = prescribed.intensity {
      let anchor =
        prescribed.effectivePercentageAnchor == .topSet
        ? " " + CoachLocalization.localized("coach.execution.topSet") : ""
      return value.formatted() + "%" + anchor
    }
    if case .weightRange(let low, let high) = prescribed.intensity {
      return "\(low.formatted())–\(high.formatted())"
    }
    return prescribed.weightKg?.formatted() ?? "—"
  }

  private var originalEffort: String? {
    guard let prescribed else { return nil }
    switch prescribed.intensity {
    case .rir(let target):
      return "RIR \(target)"
    case .rpeRange(let low, let high):
      return "RPE \(low.formatted())–\(high.formatted())"
    default:
      return prescribed.rpe.map { "RPE \($0.formatted())" } ?? "—"
    }
  }

  private var weightChanged: Bool {
    guard let prescribed else { return false }
    if case .weightRange(let low, let high) = prescribed.intensity {
      return log.weightKg.map { !(low...high).contains($0) } ?? true
    }
    if case .percentage = prescribed.intensity, prescribed.weightKg == nil {
      return false
    }
    return log.weightKg != prescribed.weightKg
  }

  private var repsChanged: Bool {
    guard let prescribed, let reps = prescribed.reps else { return false }
    return !(reps...(prescribed.repsMax ?? reps)).contains(log.reps)
  }

  private var effortChanged: Bool {
    guard let prescribed else { return false }
    switch prescribed.intensity {
    case .rir(let target): return log.actualRIR != target || log.rpe != nil
    case .rpeRange(let low, let high):
      return log.actualRIR != nil || !(log.rpe.map { (low...high).contains($0) } ?? false)
    default: return log.rpe != prescribed.rpe || log.actualRIR != nil
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
        original: originalWeight, changed: weightChanged)
      CoachSetMetric(
        actual: String(log.reps),
        original: prescribed.flatMap { set in
          guard let reps = set.reps else {
            return nil
          }
          return set.repsMax.map { "\(reps)–\($0)" } ?? String(reps)
        }, changed: repsChanged)
      if !isAccessibilitySize { Spacer(minLength: 0) }
      CoachSetMetric(
        actual: log.actualRIR.map { "RIR \($0)" } ?? log.rpe.map { "RPE \($0.formatted())" } ?? "—",
        original: originalEffort, changed: effortChanged)
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
  let changed: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(actual).foregroundStyle(
        changed ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
      if let original {
        Text(CoachLocalization.localized("coach.execution.target") + " " + original)
          .font(.caption2).foregroundStyle(Color.MeetPR.textSecondary)
      }
    }
  }
}
