import Foundation

/// The student's free-text reflection for one training day. Local-only for now
/// (no coach visibility until the backend carries it), so the summary labels it
/// as a private note rather than implying the coach reads it.
public struct SessionReflection: Codable, Equatable, Sendable {
  public var mindset: String
  public var achievements: String
  public var improvements: String

  public init(mindset: String = "", achievements: String = "", improvements: String = "") {
    self.mindset = mindset
    self.achievements = achievements
    self.improvements = improvements
  }

  public var isEmpty: Bool {
    mindset.isEmpty && achievements.isEmpty && improvements.isEmpty
  }
}

/// Persists per-day session reflections so the prompts are no longer collected
/// and silently discarded on dismiss. UserDefaults-backed in production;
/// injectable for tests. Mirrors `UserDefaultsReadinessSkipStore`.
public protocol SessionReflectionStore: Sendable {
  func reflection(studentId: UUID, date: Date) -> SessionReflection
  func save(_ reflection: SessionReflection, studentId: UUID, date: Date)
}

public struct UserDefaultsSessionReflectionStore: SessionReflectionStore {
  // UserDefaults is documented thread-safe but not yet Sendable-annotated;
  // the store needs to stay Sendable (it crosses into SwiftUI/actor contexts).
  nonisolated(unsafe) private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func reflection(studentId: UUID, date: Date) -> SessionReflection {
    guard
      let data = defaults.data(forKey: Self.key(studentId, date)),
      let stored = try? JSONDecoder().decode(SessionReflection.self, from: data)
    else { return SessionReflection() }
    return stored
  }

  public func save(_ reflection: SessionReflection, studentId: UUID, date: Date) {
    let key = Self.key(studentId, date)
    // An emptied reflection clears the record rather than storing blank strings.
    guard !reflection.isEmpty, let data = try? JSONEncoder().encode(reflection) else {
      defaults.removeObject(forKey: key)
      return
    }
    defaults.set(data, forKey: key)
  }

  /// Key granular to the local calendar day. Built from calendar components
  /// (not a shared `DateFormatter`) so the store stays `Sendable`; the day is
  /// resolved in the device's current calendar/timezone, matching how the
  /// summary presents "today".
  private static func key(_ studentId: UUID, _ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    let day = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    return "session.reflection.\(studentId.uuidString).\(day)"
  }
}
