import Foundation
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func exerciseUsageTrackerStartsAtZero() {
  let tracker = makeTracker()
  defer { tracker.resetAll() }

  let exerciseID = UUID()
  #expect(tracker.usageCount(for: exerciseID) == 0)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func exerciseUsageTrackerIncrementsCount() {
  let tracker = makeTracker()
  defer { tracker.resetAll() }

  let exerciseID = UUID()
  tracker.incrementUsage(for: exerciseID)
  tracker.incrementUsage(for: exerciseID)
  tracker.incrementUsage(for: exerciseID)

  #expect(tracker.usageCount(for: exerciseID) == 3)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func exerciseUsageTrackerTracksMultipleIDsIndependently() {
  let tracker = makeTracker()
  defer { tracker.resetAll() }

  let alpha = UUID()
  let beta = UUID()
  tracker.incrementUsage(for: alpha)
  tracker.incrementUsage(for: alpha)
  tracker.incrementUsage(for: beta)

  #expect(tracker.usageCount(for: alpha) == 2)
  #expect(tracker.usageCount(for: beta) == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func exerciseUsageTrackerPersistsAcrossInstancesInSameSuite() throws {
  let suiteName = "MeetPR.test.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }

  let exerciseID = UUID()
  let first = ExerciseUsageTracker(defaults: defaults, key: "test")
  first.incrementUsage(for: exerciseID)
  first.incrementUsage(for: exerciseID)

  let second = ExerciseUsageTracker(defaults: defaults, key: "test")
  #expect(second.usageCount(for: exerciseID) == 2)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func exerciseUsageTrackerResetClearsCounts() {
  let tracker = makeTracker()

  let exerciseID = UUID()
  tracker.incrementUsage(for: exerciseID)
  tracker.resetAll()

  #expect(tracker.usageCount(for: exerciseID) == 0)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func makeTracker() -> ExerciseUsageTracker {
  let suiteName = "MeetPR.test.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  return ExerciseUsageTracker(defaults: defaults, key: "test")
}
