import Foundation

public enum InviteCodeType: String, Codable, Hashable, Sendable, CaseIterable {
  case personalPermanent = "personal_permanent"
  case singleUse = "single_use"
  case timeLimited = "time_limited"
  case coachReferral = "coach_referral"
}
