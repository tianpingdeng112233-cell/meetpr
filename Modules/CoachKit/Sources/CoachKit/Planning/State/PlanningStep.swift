import Foundation

public enum PlanningStep: Int, CaseIterable, Codable, Hashable, Sendable {
  case selectStudent = 0
  case selectDuration = 1
  case assignFrequency = 2
  case selectMainLifts = 3
  case selectAccessories = 4
}
