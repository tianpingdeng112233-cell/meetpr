import Foundation

/// Mirrors backend INVITE_CODE_TYPES verbatim (src/db/types.ts, spec 031).
public enum InviteCodeType: String, Codable, Hashable, Sendable, CaseIterable {
  case personalPermanent = "personal_permanent"
  case singleUse = "single_use"
  case timeLimited = "time_limited"
}
