import Foundation

public enum ProgressionRuleType: String, Codable, CaseIterable, Hashable, Sendable {
  case weightInc = "weight_inc"
  case weightDec = "weight_dec"
  case rpeInc = "rpe_inc"
  case rpeDec = "rpe_dec"
  case setsInc = "sets_inc"
  case setsDec = "sets_dec"
  case repsInc = "reps_inc"
  case repsDec = "reps_dec"
  case custom

  public var dimension: ProgressionRuleDimension? {
    switch self {
    case .weightInc, .weightDec:
      .weight
    case .rpeInc, .rpeDec:
      .rpe
    case .setsInc, .setsDec:
      .sets
    case .repsInc, .repsDec:
      .reps
    case .custom:
      nil
    }
  }

  public var title: String {
    switch self {
    case .weightInc:
      CoachPlanningStrings.weightIncrease
    case .weightDec:
      CoachPlanningStrings.weightDecrease
    case .rpeInc:
      CoachPlanningStrings.rpeIncrease
    case .rpeDec:
      CoachPlanningStrings.rpeDecrease
    case .setsInc:
      CoachPlanningStrings.setIncrease
    case .setsDec:
      CoachPlanningStrings.setDecrease
    case .repsInc:
      CoachPlanningStrings.repIncrease
    case .repsDec:
      CoachPlanningStrings.repDecrease
    case .custom:
      CoachPlanningStrings.custom
    }
  }
}
