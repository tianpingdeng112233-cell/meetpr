import Foundation

public enum StudentRestTimerPreference: Equatable, Sendable {
  public static let fixedRange = 30...600
  public static let fixedStep = 15
  public static let defaultFixedSeconds = 180

  case automatic
  case fixed(seconds: Int)

  public var fixedSeconds: Int? {
    guard case .fixed(let seconds) = self else { return nil }
    return seconds
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
    guard
      let seconds = defaults.object(forKey: preferenceKey(for: studentID)) as? Int,
      Self.isSupportedFixedDuration(seconds)
    else { return .automatic }
    return .fixed(seconds: seconds)
  }

  public func setPreference(_ preference: StudentRestTimerPreference, for studentID: UUID) {
    let key = preferenceKey(for: studentID)
    switch preference {
    case .automatic:
      defaults.removeObject(forKey: key)
    case .fixed(let seconds):
      guard Self.isSupportedFixedDuration(seconds) else { return }
      defaults.set(seconds, forKey: key)
    }
  }

  public func hasAcknowledgedExplanation(for studentID: UUID) -> Bool {
    defaults.bool(forKey: explanationKey(for: studentID))
  }

  public func markExplanationAcknowledged(for studentID: UUID) {
    defaults.set(true, forKey: explanationKey(for: studentID))
  }

  private static func isSupportedFixedDuration(_ seconds: Int) -> Bool {
    StudentRestTimerPreference.fixedRange.contains(seconds)
      && seconds.isMultiple(of: StudentRestTimerPreference.fixedStep)
  }

  private func preferenceKey(for studentID: UUID) -> String {
    "meetpr.student.rest_timer.fixed_seconds.\(studentID.uuidString)"
  }

  private func explanationKey(for studentID: UUID) -> String {
    "meetpr.student.rest_timer.explanation_acknowledged.\(studentID.uuidString)"
  }
}
