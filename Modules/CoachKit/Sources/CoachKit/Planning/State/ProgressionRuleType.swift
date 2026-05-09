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
      "重量递增"
    case .weightDec:
      "重量递减"
    case .rpeInc:
      "RPE 递增"
    case .rpeDec:
      "RPE 递减"
    case .setsInc:
      "组数递增"
    case .setsDec:
      "组数递减"
    case .repsInc:
      "次数递增"
    case .repsDec:
      "次数递减"
    case .custom:
      "自定义"
    }
  }
}
