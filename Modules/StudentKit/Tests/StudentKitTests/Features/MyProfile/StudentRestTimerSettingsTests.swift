import Foundation
import Testing

@testable import StudentKit

@Test func restTimerSettingsDefaultToAutomaticAndPersistCustomBands() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()
  let preference = StudentRestTimerPreference.custom(
    lowSeconds: 105,
    midSeconds: 195,
    highSeconds: 315
  )

  #expect(testStore.store.preference(for: studentID) == .automatic)

  testStore.store.setPreference(preference, for: studentID)
  #expect(testStore.store.preference(for: studentID) == preference)

  testStore.store.setPreference(.automatic, for: studentID)
  #expect(testStore.store.preference(for: studentID) == .automatic)
}

@Test func restTimerPreferenceIsIsolatedPerStudent() throws {
  let firstStudentID = UUID()
  let secondStudentID = UUID()
  let testStore = try makeTestStore()

  let preference = StudentRestTimerPreference.custom(
    lowSeconds: 120,
    midSeconds: 180,
    highSeconds: 240
  )
  testStore.store.setPreference(preference, for: firstStudentID)
  #expect(testStore.store.preference(for: firstStudentID) == preference)
  #expect(testStore.store.preference(for: secondStudentID) == .automatic)
}

@Test func restTimerSettingsRejectUnsupportedCustomDurations() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()

  testStore.store.setPreference(
    .custom(lowSeconds: 100, midSeconds: 180, highSeconds: 240),
    for: studentID
  )
  #expect(testStore.store.preference(for: studentID) == .automatic)
  testStore.store.setPreference(
    .custom(lowSeconds: 120, midSeconds: 615, highSeconds: 240),
    for: studentID
  )
  #expect(testStore.store.preference(for: studentID) == .automatic)
  testStore.store.setPreference(
    .custom(lowSeconds: 120, midSeconds: 180, highSeconds: 15),
    for: studentID
  )
  #expect(testStore.store.preference(for: studentID) == .automatic)
}

@Test func legacyFixedDurationMigratesToThreeEqualBands() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()
  let key = preferenceKey(for: studentID)

  testStore.defaults.set(195, forKey: key)

  #expect(
    testStore.store.preference(for: studentID)
      == .custom(lowSeconds: 195, midSeconds: 195, highSeconds: 195)
  )
  #expect(testStore.defaults.data(forKey: key) != nil)
}

@Test func restTimerPreferenceFallsBackToAutomaticOnCorruptPersistedValue() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()
  let key = preferenceKey(for: studentID)

  testStore.defaults.set(Data("not-json".utf8), forKey: key)
  #expect(testStore.store.preference(for: studentID) == .automatic)

  testStore.defaults.set(
    Data(#"{"version":2,"lowSeconds":100,"midSeconds":180,"highSeconds":240}"#.utf8),
    forKey: key
  )
  #expect(testStore.store.preference(for: studentID) == .automatic)

  testStore.defaults.set(47, forKey: key)
  #expect(testStore.store.preference(for: studentID) == .automatic)

  testStore.defaults.set("not-a-number", forKey: key)
  #expect(testStore.store.preference(for: studentID) == .automatic)
}

@Test func unsupportedPersistedVersionFallsBackToAutomatic() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()
  let key = preferenceKey(for: studentID)

  // Well-formed flat payload (the real Codable shape), valid durations, but
  // a future/unknown version tag: only the version gate should reject it.
  let payload: [String: Any] = [
    "version": 99,
    "lowSeconds": 120,
    "midSeconds": 180,
    "highSeconds": 240,
  ]
  testStore.defaults.set(
    try JSONSerialization.data(withJSONObject: payload),
    forKey: key
  )
  #expect(testStore.store.preference(for: studentID) == .automatic)
}

@Test func migratedLegacyValueRoundTripsThroughCurrentFormat() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()
  let key = preferenceKey(for: studentID)

  testStore.defaults.set(150, forKey: key)
  let migrated = testStore.store.preference(for: studentID)
  #expect(
    migrated == .custom(lowSeconds: 150, midSeconds: 150, highSeconds: 150)
  )

  // Read again through a FRESH store on the same defaults: whatever the
  // migration wrote back must decode through the current-version path on
  // its own, with no manual rewrite masking a corrupt payload.
  let rereadStore = UserDefaultsRestTimerSettingsStore(defaults: testStore.defaults)
  #expect(rereadStore.preference(for: studentID) == migrated)
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

private func preferenceKey(for studentID: UUID) -> String {
  "meetpr.student.rest_timer.fixed_seconds.\(studentID.uuidString)"
}

@Test func accessoryRestUsesIndependentKeyAndPreservesLegacyPreferences() throws {
  let studentID = UUID()
  let testStore = try makeTestStore()
  let accessoryKey = "meetpr.student.rest_timer.accessory_seconds.\(studentID.uuidString)"
  let mainKey = preferenceKey(for: studentID)
  #expect(testStore.store.accessorySeconds(for: studentID) == 60)
  let oldJSON = Data(#"{"version":2,"lowSeconds":105,"midSeconds":195,"highSeconds":315}"#.utf8)
  testStore.defaults.set(oldJSON, forKey: mainKey)
  #expect(
    testStore.store.preference(for: studentID)
      == .custom(lowSeconds: 105, midSeconds: 195, highSeconds: 315))
  #expect(testStore.store.accessorySeconds(for: studentID) == 60)
  #expect(testStore.defaults.data(forKey: mainKey) == oldJSON)
  testStore.defaults.set(195, forKey: mainKey)
  #expect(
    testStore.store.preference(for: studentID)
      == .custom(lowSeconds: 195, midSeconds: 195, highSeconds: 195))
  #expect(testStore.store.accessorySeconds(for: studentID) == 60)
  testStore.store.setAccessorySeconds(90, for: studentID)
  #expect(testStore.store.accessorySeconds(for: studentID) == 90)
  #expect(testStore.store.accessorySeconds(for: UUID()) == 60)
  testStore.store.setPreference(.automatic, for: studentID)
  #expect(testStore.defaults.object(forKey: mainKey) == nil)
  #expect(testStore.store.accessorySeconds(for: studentID) == 90)
  testStore.store.setPreference(.defaultCustom, for: studentID)
  #expect(testStore.store.accessorySeconds(for: studentID) == 90)
  testStore.store.setPreference(.automatic, for: studentID)
  #expect(testStore.store.accessorySeconds(for: studentID) == 90)
  for invalid in [0, 29, 31, 301, 600] {
    testStore.defaults.set(invalid, forKey: accessoryKey)
    #expect(testStore.store.accessorySeconds(for: studentID) == 60)
  }
  testStore.defaults.set("90", forKey: accessoryKey)
  #expect(testStore.store.accessorySeconds(for: studentID) == 60)
}
