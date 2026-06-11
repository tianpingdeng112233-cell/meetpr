import Foundation

/// Code + display name captured by the enter-code page, parked while the
/// student walks the 7-step onboarding wizard (spec 031 §4 — defined by 031,
/// consumed by 032's complete handoff).
public struct PendingBindCode: Codable, Equatable, Sendable {
  /// Normalized: uppercased, separators stripped (InviteCodeFormat).
  public let code: String
  public let displayName: String
  public let stashedAt: Date

  public init(code: String, displayName: String, stashedAt: Date) {
    self.code = code
    self.displayName = displayName
    self.stashedAt = stashedAt
  }
}

/// Stash lifecycle (spec 031 §4, mirrored in 032 §6 — change both together):
/// - write: enter-code submit while onboarding is incomplete;
/// - read: ① 032 complete handoff ② BindGate cold-start resume;
/// - clear: bind request 201 or INVITE_CODE_INVALID (display name flows back
///   into the enter-code prefill);
/// - keep: network failure / already-pending / already-bound (the state
///   machine converges after the next reload).
public protocol PendingBindCodeStoring: Sendable {
  func stash(_ pending: PendingBindCode, studentId: UUID)
  func peek(studentId: UUID) -> PendingBindCode?
  func clear(studentId: UUID)
}

/// UserDefaults-backed (spec 031 D2): invite codes are coach-distributed
/// non-secrets, the payload is <200B, and the key is namespaced per student.
/// Holds a suite name instead of the (non-Sendable) UserDefaults instance.
public struct UserDefaultsPendingBindCodeStore: PendingBindCodeStoring {
  private let suiteName: String?

  /// `suiteName` is test-injection; production uses `.standard`.
  public init(suiteName: String? = nil) {
    self.suiteName = suiteName
  }

  private var defaults: UserDefaults {
    suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
  }

  public func stash(_ pending: PendingBindCode, studentId: UUID) {
    guard let data = try? JSONEncoder().encode(pending) else { return }
    defaults.set(data, forKey: Self.key(studentId))
  }

  public func peek(studentId: UUID) -> PendingBindCode? {
    guard let data = defaults.data(forKey: Self.key(studentId)) else { return nil }
    return try? JSONDecoder().decode(PendingBindCode.self, from: data)
  }

  public func clear(studentId: UUID) {
    defaults.removeObject(forKey: Self.key(studentId))
  }

  private static func key(_ studentId: UUID) -> String {
    "bind.pendingCode.\(studentId.uuidString)"
  }
}
