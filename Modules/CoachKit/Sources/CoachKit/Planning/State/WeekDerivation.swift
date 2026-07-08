import CoreModels
import Foundation

public enum WeekDerivation {
  public static func deriveSetSpec(
    forWeek weekN: Int,
    exerciseID: UUID,
    w1 weekOne: DraftSetSpec,
    rules: [DraftProgressionRule]
  ) -> DraftSetSpec {
    guard weekN > 1 else { return weekOne }

    var current = weekOne
    for week in 2...weekN {
      current = deriveNextWeek(
        week,
        exerciseID: exerciseID,
        previous: current,
        rules: rules
      )
    }
    return current
  }

  private static func deriveNextWeek(
    _ week: Int,
    exerciseID: UUID,
    previous: DraftSetSpec,
    rules: [DraftProgressionRule]
  ) -> DraftSetSpec {
    let matchingRules = rules.filter { rule in
      rule.appliedWeeks.contains(week) && rule.exerciseIDs.contains(exerciseID)
    }
    guard !matchingRules.isEmpty else { return previous }

    var derived = previous
    for dimension in ProgressionRuleDimension.allCases {
      guard
        let rule =
          matchingRules
          .filter({ ruleDimension($0) == dimension })
          .max(by: { $0.displayOrder < $1.displayOrder })
      else {
        continue
      }
      apply(rule, dimension: dimension, week: week, to: &derived)
    }
    return clamped(derived)
  }

  private static func ruleDimension(_ rule: DraftProgressionRule) -> ProgressionRuleDimension? {
    rule.ruleType.dimension ?? rule.customDimension
  }

  private static func apply(
    _ rule: DraftProgressionRule,
    dimension: ProgressionRuleDimension,
    week: Int,
    to spec: inout DraftSetSpec
  ) {
    if rule.ruleType == .custom {
      applyCustom(rule, dimension: dimension, week: week, to: &spec)
      return
    }

    let delta = rule.incrementValue ?? 0
    switch rule.ruleType {
    case .weightInc:
      spec.intensityMode = .weight
      spec.targetValue += delta
      applyToPerSetTargets(&spec) { target in
        target.intensityMode = .weight
        target.targetValue += delta
      }
    case .weightDec:
      spec.intensityMode = .weight
      spec.targetValue -= delta
      applyToPerSetTargets(&spec) { target in
        target.intensityMode = .weight
        target.targetValue -= delta
      }
    case .rpeInc:
      spec.intensityMode = .rpe
      spec.targetValue += delta
      applyToPerSetTargets(&spec) { target in
        target.intensityMode = .rpe
        target.targetValue += delta
      }
    case .rpeDec:
      spec.intensityMode = .rpe
      spec.targetValue -= delta
      applyToPerSetTargets(&spec) { target in
        target.intensityMode = .rpe
        target.targetValue -= delta
      }
    case .setsInc:
      spec.setCount += intValue(delta)
    case .setsDec:
      spec.setCount -= intValue(delta)
    case .repsInc:
      spec.targetReps += intValue(delta)
      applyToPerSetTargets(&spec) { target in
        target.targetReps += intValue(delta)
      }
    case .repsDec:
      spec.targetReps -= intValue(delta)
      applyToPerSetTargets(&spec) { target in
        target.targetReps -= intValue(delta)
      }
    case .custom:
      break
    }
  }

  private static func applyCustom(
    _ rule: DraftProgressionRule,
    dimension: ProgressionRuleDimension,
    week: Int,
    to spec: inout DraftSetSpec
  ) {
    let sortedWeeks = rule.appliedWeeks.sorted()
    guard
      let weekIndex = sortedWeeks.firstIndex(of: week),
      let customSequence = rule.customSequence,
      customSequence.indices.contains(weekIndex)
    else {
      return
    }

    let value = customSequence[weekIndex]
    switch dimension {
    case .weight:
      spec.intensityMode = .weight
      spec.targetValue = value
      applyToPerSetTargets(&spec) { target in
        target.intensityMode = .weight
        target.targetValue = value
      }
    case .rpe:
      spec.intensityMode = .rpe
      spec.targetValue = value
      applyToPerSetTargets(&spec) { target in
        target.intensityMode = .rpe
        target.targetValue = value
      }
    case .sets:
      spec.setCount = intValue(value)
    case .reps:
      spec.targetReps = intValue(value)
      applyToPerSetTargets(&spec) { target in
        target.targetReps = intValue(value)
      }
    }
  }

  private static func clamped(_ spec: DraftSetSpec) -> DraftSetSpec {
    var next = spec
    next.setCount = max(1, next.setCount)
    next.targetReps = max(1, next.targetReps)
    if let targetRepsMax = next.targetRepsMax {
      next.targetRepsMax = max(next.targetReps, targetRepsMax)
    }
    if next.intensityMode == .rpe {
      next.targetValue = min(Decimal(10), max(Decimal(1), next.targetValue))
    } else {
      next.targetValue = max(Decimal(0), next.targetValue)
    }
    if next.perSetTargets != nil {
      next.perSetTargets = normalizedPerSetTargets(for: next).map(clampedTarget)
      syncSummaryFromFirstPerSetTarget(&next)
    }
    return next
  }

  private static func applyToPerSetTargets(
    _ spec: inout DraftSetSpec,
    transform: (inout DraftSetTarget) -> Void
  ) {
    guard var targets = spec.perSetTargets else { return }
    for index in targets.indices {
      transform(&targets[index])
    }
    spec.perSetTargets = targets
  }

  private static func normalizedPerSetTargets(for spec: DraftSetSpec) -> [DraftSetTarget] {
    var targets = spec.perSetTargets ?? []
    let desiredCount = max(1, spec.setCount)
    if targets.count > desiredCount {
      targets.removeLast(targets.count - desiredCount)
    } else if targets.count < desiredCount {
      let fill = targets.last ?? spec.baseTarget
      targets.append(contentsOf: repeatElement(fill, count: desiredCount - targets.count))
    }
    return targets
  }

  private static func clampedTarget(_ target: DraftSetTarget) -> DraftSetTarget {
    var next = target
    next.targetReps = max(1, next.targetReps)
    if let targetRepsMax = next.targetRepsMax {
      next.targetRepsMax = max(next.targetReps, targetRepsMax)
    }
    switch next.intensityMode {
    case .weight:
      next.targetValue = max(Decimal(0), next.targetValue)
    case .rpe:
      next.targetValue = min(Decimal(10), max(Decimal(1), next.targetValue))
    }
    return next
  }

  private static func syncSummaryFromFirstPerSetTarget(_ spec: inout DraftSetSpec) {
    guard let first = spec.perSetTargets?.first else { return }
    spec.targetReps = first.targetReps
    spec.targetRepsMax = first.targetRepsMax
    spec.intensityMode = first.intensityMode
    spec.targetValue = first.targetValue
    spec.setType = first.setType
  }

  private static func intValue(_ decimal: Decimal) -> Int {
    NSDecimalNumber(decimal: decimal).intValue
  }
}
