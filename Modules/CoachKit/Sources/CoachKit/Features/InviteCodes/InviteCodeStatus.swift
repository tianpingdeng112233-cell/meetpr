import CoreModels
import Foundation

/// Client-derived code status (spec 031 D7): the wire has no status column —
/// revocation, exhaustion, and expiry are computed at read time against an
/// injected clock (risk 7: never a bare Date() in the rules), matching the
/// backend's lazy-expiry semantics.
public enum InviteCodeStatus: Equatable, Sendable {
  case active
  /// time_limited with a future expiry — carries the remaining whole days
  /// (ceiling) for the "X 天后过期" label.
  case expiringIn(days: Int)
  case used
  case expired
  case revoked

  public static func status(of code: InviteCode, now: Date) -> InviteCodeStatus {
    if code.revokedAt != nil {
      return .revoked
    }
    if code.type == .singleUse, let maxUses = code.maxUses, code.usedCount >= maxUses {
      return .used
    }
    if let expiresAt = code.expiresAt {
      guard expiresAt > now else { return .expired }
      let remaining = expiresAt.timeIntervalSince(now)
      return .expiringIn(days: max(1, Int(ceil(remaining / 86_400))))
    }
    return .active
  }

  public var label: String {
    switch self {
    case .active: InviteCodeStrings.statusActive
    case .expiringIn(let days): InviteCodeStrings.expiresIn(days)
    case .used: InviteCodeStrings.statusUsed
    case .expired: InviteCodeStrings.statusExpired
    case .revoked: InviteCodeStrings.statusRevoked
    }
  }

  /// Live codes can be copied/revoked; defunct ones sink to the lower
  /// section (spec 031 §8).
  public var isDefunct: Bool {
    switch self {
    case .active, .expiringIn: false
    case .used, .expired, .revoked: true
    }
  }
}
