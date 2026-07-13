import Foundation

actor AnalyticsSessionStore {
  struct Metadata: Equatable, Sendable {
    let anonID: UUID
    let sessionID: UUID
    let seq: Int
  }

  private let defaults: UserDefaults
  private let anonIDKey: String
  private let now: @Sendable () -> Date
  private let sessionTimeout: TimeInterval
  private(set) var anonID: UUID
  private(set) var sessionID: UUID
  private var seq = 0
  private var backgroundedAt: Date?

  init(
    defaults: UserDefaults = .standard,
    keyPrefix: String = "meetpr.analytics",
    sessionTimeout: TimeInterval = 1_800,
    now: @escaping @Sendable () -> Date = { Date() },
    uuid: @escaping @Sendable () -> UUID = { UUID() }
  ) {
    self.defaults = defaults
    self.anonIDKey = "\(keyPrefix).anon_id"
    self.sessionTimeout = sessionTimeout
    self.now = now
    if let stored = defaults.string(forKey: anonIDKey), let identifier = UUID(uuidString: stored) {
      anonID = identifier
    } else {
      let identifier = uuid()
      anonID = identifier
      defaults.set(identifier.uuidString.lowercased(), forKey: anonIDKey)
    }
    sessionID = uuid()
  }

  func next() -> Metadata {
    let metadata = Metadata(anonID: anonID, sessionID: sessionID, seq: seq)
    seq += 1
    return metadata
  }

  func current() -> Metadata {
    Metadata(anonID: anonID, sessionID: sessionID, seq: seq)
  }

  func didEnterBackground() {
    backgroundedAt = now()
  }

  func willEnterForeground(uuid: @Sendable () -> UUID = { UUID() }) {
    defer { backgroundedAt = nil }
    guard let backgroundedAt, now().timeIntervalSince(backgroundedAt) >= sessionTimeout else {
      return
    }
    sessionID = uuid()
    seq = 0
  }
}
