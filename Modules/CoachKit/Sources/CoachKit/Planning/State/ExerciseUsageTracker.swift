import Foundation

/// Tracks how often each exercise (by id) has been picked by the coach.
/// Used to surface frequently-used variants to the top of the picker.
///
/// Persistence: UserDefaults dict keyed by UUID string → count.
@MainActor
public final class ExerciseUsageTracker {
  private let defaults: UserDefaults
  private let key: String

  public init(
    defaults: UserDefaults = .standard,
    key: String = "MeetPR.exerciseUsageCounts"
  ) {
    self.defaults = defaults
    self.key = key
  }

  public func usageCount(for exerciseID: UUID) -> Int {
    currentCounts()[exerciseID.uuidString] ?? 0
  }

  public func incrementUsage(for exerciseID: UUID) {
    var counts = currentCounts()
    counts[exerciseID.uuidString, default: 0] += 1
    defaults.set(counts, forKey: key)
  }

  public func resetAll() {
    defaults.removeObject(forKey: key)
  }

  private func currentCounts() -> [String: Int] {
    defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
  }
}
