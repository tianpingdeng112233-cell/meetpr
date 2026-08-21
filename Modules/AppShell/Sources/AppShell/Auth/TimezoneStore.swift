import Foundation

public protocol TimezoneStoring: Sendable {
  func lastReportedIdentifier(for userID: UUID) async -> String?
  func saveReportedIdentifier(_ identifier: String, for userID: UUID) async
}

public actor UserDefaultsTimezoneStore: TimezoneStoring {
  private static let storageKeyPrefix = "auth.lastReportedTimezone"

  private let defaults: UserDefaults

  public init(suiteName: String? = nil) {
    if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
      self.defaults = defaults
    } else {
      defaults = .standard
    }
  }

  public func lastReportedIdentifier(for userID: UUID) -> String? {
    defaults.string(forKey: Self.storageKey(for: userID))
  }

  public func saveReportedIdentifier(_ identifier: String, for userID: UUID) {
    defaults.set(identifier, forKey: Self.storageKey(for: userID))
  }

  private static func storageKey(for userID: UUID) -> String {
    "\(storageKeyPrefix).\(userID.uuidString.lowercased())"
  }
}
