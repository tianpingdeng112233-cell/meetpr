import Foundation

/// The coach's quick-% buttons above the weight calculator (David 2026-06-14
/// — these became editable). Pure normalization so the rules test in
/// isolation; persistence is behind a protocol so previews/tests stay
/// off UserDefaults.
public enum WeightPercentPresets {
  public static let fallback = [60, 70, 75, 80, 85, 90]
  public static let maxCount = 8

  /// Clamp to 1…99, drop dupes, sort ascending, cap the count. An all-invalid
  /// input falls back to the defaults so the row is never empty.
  public static func normalized(_ raw: [Int]) -> [Int] {
    let cleaned = Array(Set(raw.filter { (1...99).contains($0) })).sorted()
    guard !cleaned.isEmpty else { return fallback }
    return Array(cleaned.prefix(maxCount))
  }
}

public protocol WeightPercentPresetStoring: Sendable {
  func load() -> [Int]
  func save(_ values: [Int])
}

public struct UserDefaultsWeightPercentPresetStore: WeightPercentPresetStoring, @unchecked Sendable
{
  private let defaults: UserDefaults
  private let key = "coach.planning.weightPercentPresets"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func load() -> [Int] {
    guard let stored = defaults.array(forKey: key) as? [Int] else {
      return WeightPercentPresets.fallback
    }
    return WeightPercentPresets.normalized(stored)
  }

  public func save(_ values: [Int]) {
    defaults.set(WeightPercentPresets.normalized(values), forKey: key)
  }
}
