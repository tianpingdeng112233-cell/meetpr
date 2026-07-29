import Foundation

public struct StudentRestTimerDurations: Equatable, Sendable {
  public let low: Int
  public let mid: Int
  public let high: Int

  public init(low: Int, mid: Int, high: Int) {
    self.low = low
    self.mid = mid
    self.high = high
  }
}

public enum StudentRestTimerPreference: Equatable, Sendable {
  public static let durationRange = 30...600
  public static let durationStep = 15
  public static let defaultLowSeconds = 120
  public static let defaultMidSeconds = 180
  public static let defaultHighSeconds = 240

  case automatic
  case custom(lowSeconds: Int, midSeconds: Int, highSeconds: Int)

  public static var defaultCustom: Self {
    .custom(
      lowSeconds: defaultLowSeconds,
      midSeconds: defaultMidSeconds,
      highSeconds: defaultHighSeconds
    )
  }

  public var customSeconds: StudentRestTimerDurations? {
    guard case .custom(let low, let mid, let high) = self else { return nil }
    return StudentRestTimerDurations(low: low, mid: mid, high: high)
  }

  public func customSeconds(forRPE rpe: Decimal?) -> Int? {
    guard let seconds = customSeconds else { return nil }
    guard let rpe else { return seconds.mid }
    if rpe < 7 { return seconds.low }
    if rpe < 9 { return seconds.mid }
    return seconds.high
  }
}

enum StudentRestTimerCopy {
  static let automaticModeTitle = "自动(按 RPE)"
  static let automaticSummary = "自动 (按 RPE)"
  // ⚖️ David 2026-07-28.
  static let customModeTitle = "手动设置"

  static func summary(for preference: StudentRestTimerPreference) -> String {
    guard let seconds = preference.customSeconds else { return automaticSummary }
    let durations = [
      durationText(seconds.low),
      durationText(seconds.mid),
      durationText(seconds.high),
    ]
    return "\(customModeTitle) \(durations.joined(separator: "/"))"
  }

  static func durationText(_ seconds: Int) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
  }
}

/// Device-local student rest-timer settings. The backend deliberately has no
/// matching preference in this release, so both the fallback and the one-time
/// explanation flag live in UserDefaults and remain injectable for tests.
public protocol StudentRestTimerSettingsStoring: Sendable {
  func preference(for studentID: UUID) -> StudentRestTimerPreference
  func setPreference(_ preference: StudentRestTimerPreference, for studentID: UUID)
  func hasAcknowledgedExplanation(for studentID: UUID) -> Bool
  func markExplanationAcknowledged(for studentID: UUID)
}

public struct UserDefaultsRestTimerSettingsStore: StudentRestTimerSettingsStoring {
  nonisolated(unsafe) private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func preference(for studentID: UUID) -> StudentRestTimerPreference {
    let key = preferenceKey(for: studentID)
    if let data = defaults.data(forKey: key),
      let persisted = try? JSONDecoder().decode(PersistedPreference.self, from: data),
      persisted.version == PersistedPreference.currentVersion,
      Self.isSupportedCustomPreference(persisted.preference)
    {
      return persisted.preference
    }

    guard
      let legacySeconds = defaults.object(forKey: key) as? Int,
      Self.isSupportedDuration(legacySeconds)
    else { return .automatic }

    let migrated = StudentRestTimerPreference.custom(
      lowSeconds: legacySeconds,
      midSeconds: legacySeconds,
      highSeconds: legacySeconds
    )
    setPreference(migrated, for: studentID)
    return migrated
  }

  public func setPreference(_ preference: StudentRestTimerPreference, for studentID: UUID) {
    let key = preferenceKey(for: studentID)
    switch preference {
    case .automatic:
      defaults.removeObject(forKey: key)
    case .custom:
      guard
        Self.isSupportedCustomPreference(preference),
        let data = try? JSONEncoder().encode(PersistedPreference(preference: preference))
      else { return }
      defaults.set(data, forKey: key)
    }
  }

  public func hasAcknowledgedExplanation(for studentID: UUID) -> Bool {
    defaults.bool(forKey: explanationKey(for: studentID))
  }

  public func markExplanationAcknowledged(for studentID: UUID) {
    defaults.set(true, forKey: explanationKey(for: studentID))
  }

  private static func isSupportedCustomPreference(
    _ preference: StudentRestTimerPreference
  ) -> Bool {
    guard let seconds = preference.customSeconds else { return false }
    return isSupportedDuration(seconds.low)
      && isSupportedDuration(seconds.mid)
      && isSupportedDuration(seconds.high)
  }

  private static func isSupportedDuration(_ seconds: Int) -> Bool {
    StudentRestTimerPreference.durationRange.contains(seconds)
      && seconds.isMultiple(of: StudentRestTimerPreference.durationStep)
  }

  private func preferenceKey(for studentID: UUID) -> String {
    "meetpr.student.rest_timer.fixed_seconds.\(studentID.uuidString)"
  }

  private func explanationKey(for studentID: UUID) -> String {
    "meetpr.student.rest_timer.explanation_acknowledged.\(studentID.uuidString)"
  }
}

private struct PersistedPreference: Codable {
  static let currentVersion = 2

  let version: Int
  let lowSeconds: Int
  let midSeconds: Int
  let highSeconds: Int

  init(preference: StudentRestTimerPreference) {
    let seconds = preference.customSeconds
    self.version = Self.currentVersion
    self.lowSeconds = seconds?.low ?? StudentRestTimerPreference.defaultLowSeconds
    self.midSeconds = seconds?.mid ?? StudentRestTimerPreference.defaultMidSeconds
    self.highSeconds = seconds?.high ?? StudentRestTimerPreference.defaultHighSeconds
  }

  var preference: StudentRestTimerPreference {
    .custom(lowSeconds: lowSeconds, midSeconds: midSeconds, highSeconds: highSeconds)
  }
}
