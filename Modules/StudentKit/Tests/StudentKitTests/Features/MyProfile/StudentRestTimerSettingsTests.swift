import Foundation
import Testing

@testable import StudentKit

@Test func restTimerSettingsDefaultToAutomaticAndPersistFixedDuration() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()

  #expect(testStore.store.preference(for: studentID) == .automatic)

  testStore.store.setPreference(.fixed(seconds: 195), for: studentID)
  #expect(testStore.store.preference(for: studentID) == .fixed(seconds: 195))

  testStore.store.setPreference(.automatic, for: studentID)
  #expect(testStore.store.preference(for: studentID) == .automatic)
}

@Test func restTimerPreferenceIsIsolatedPerStudent() throws {
  let firstStudentID = UUID()
  let secondStudentID = UUID()
  let testStore = try makeTestStore()

  testStore.store.setPreference(.fixed(seconds: 150), for: firstStudentID)
  #expect(testStore.store.preference(for: firstStudentID) == .fixed(seconds: 150))
  #expect(testStore.store.preference(for: secondStudentID) == .automatic)
}

@Test func restTimerSettingsRejectUnsupportedFixedDurations() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()

  testStore.store.setPreference(.fixed(seconds: 100), for: studentID)
  #expect(testStore.store.preference(for: studentID) == .automatic)
  testStore.store.setPreference(.fixed(seconds: 615), for: studentID)
  #expect(testStore.store.preference(for: studentID) == .automatic)
  testStore.store.setPreference(.fixed(seconds: 15), for: studentID)
  #expect(testStore.store.preference(for: studentID) == .automatic)
}

@Test func restTimerPreferenceFallsBackToAutomaticOnCorruptPersistedValue() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()

  testStore.defaults.set(
    47, forKey: "meetpr.student.rest_timer.fixed_seconds.\(studentID.uuidString)")
  #expect(testStore.store.preference(for: studentID) == .automatic)

  testStore.defaults.set(
    "not-a-number", forKey: "meetpr.student.rest_timer.fixed_seconds.\(studentID.uuidString)")
  #expect(testStore.store.preference(for: studentID) == .automatic)
}

@Test func restTimerExplanationFlagPersistsPerStudent() throws {
  let firstStudentID = UUID()
  let secondStudentID = UUID()
  let testStore = try makeTestStore()

  #expect(!testStore.store.hasAcknowledgedExplanation(for: firstStudentID))
  testStore.store.markExplanationAcknowledged(for: firstStudentID)
  #expect(testStore.store.hasAcknowledgedExplanation(for: firstStudentID))
  #expect(!testStore.store.hasAcknowledgedExplanation(for: secondStudentID))
}

private func makeTestStore() throws -> (
  store: UserDefaultsRestTimerSettingsStore, defaults: UserDefaults
) {
  let suiteName = "test.student-rest-settings.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defaults.removePersistentDomain(forName: suiteName)
  return (UserDefaultsRestTimerSettingsStore(defaults: defaults), defaults)
}
