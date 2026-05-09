import Foundation

public enum ProgressionRuleDimension: String, Codable, CaseIterable, Hashable, Sendable {
  case weight
  case rpe
  case sets
  case reps
}
