import Foundation

/// Canonical load representation written by backend plan contract v2.1.
/// A missing value identifies a legacy row whose `intensityMode` and
/// `targetValue` remain authoritative.
public enum PlanLoadMode: String, Codable, CaseIterable, Sendable {
  case percentage = "pct"
  case rpe
  case rir
  case weightRange = "weight_range"
  case rpeRange = "rpe_range"
  case fixedWeight = "fixed_weight"
}
