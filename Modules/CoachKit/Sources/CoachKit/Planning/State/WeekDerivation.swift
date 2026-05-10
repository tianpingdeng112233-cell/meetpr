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
    case .weightDec:
      spec.intensityMode = .weight
      spec.targetValue -= delta
    case .rpeInc:
      spec.intensityMode = .rpe
      spec.targetValue += delta
    case .rpeDec:
      spec.intensityMode = .rpe
      spec.targetValue -= delta
    case .setsInc:
      spec.setCount += intValue(delta)
    case .setsDec:
      spec.setCount -= intValue(delta)
    case .repsInc:
      spec.targetReps += intValue(delta)
    case .repsDec:
      spec.targetReps -= intValue(delta)
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
    case .rpe:
      spec.intensityMode = .rpe
      spec.targetValue = value
    case .sets:
      spec.setCount = intValue(value)
    case .reps:
      spec.targetReps = intValue(value)
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
    return next
  }

  private static func intValue(_ decimal: Decimal) -> Int {
    NSDecimalNumber(decimal: decimal).intValue
  }
}
