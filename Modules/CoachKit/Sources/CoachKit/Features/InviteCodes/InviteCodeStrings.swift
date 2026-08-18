import Foundation

enum InviteCodeStrings {
  static let navigationTitle = CoachLocalization.localized("coach.invites.navigationTitle")
  static let personalSection = CoachLocalization.localized("coach.invites.personalSection")
  static let secondarySection = CoachLocalization.localized("coach.invites.secondarySection")
  static let defunctSection = CoachLocalization.localized("coach.invites.defunctSection")
  static let regenerateTitle = CoachLocalization.localized("coach.invites.regenerateTitle")
  static let regenerate = CoachLocalization.localized("coach.invites.regenerate")
  static let regenerateMessage = CoachLocalization.localized("coach.invites.regenerateMessage")
  static let cancel = CoachLocalization.localized("coach.invites.cancel")
  static let revokeTitle = CoachLocalization.localized("coach.invites.revokeTitle")
  static let revoke = CoachLocalization.localized("coach.invites.revoke")
  static let revokeMessage = CoachLocalization.localized("coach.invites.revokeMessage")
  static let copy = CoachLocalization.localized("coach.invites.copy")
  static let copied = CoachLocalization.localized("coach.invites.copied")
  static let noPermanentCode = CoachLocalization.localized("coach.invites.noPermanentCode")
  static let generatePermanentCode = CoachLocalization.localized(
    "coach.invites.generatePermanentCode"
  )
  static let singleUseCode = CoachLocalization.localized("coach.invites.singleUseCode")
  static let timeLimitedCode = CoachLocalization.localized("coach.invites.timeLimitedCode")
  static let singleUse = CoachLocalization.localized("coach.invites.singleUse")
  static let timeLimited = CoachLocalization.localized("coach.invites.timeLimited")
  static let createSingleUse = CoachLocalization.localized("coach.invites.createSingleUse")
  static let createTimeLimited = CoachLocalization.localized("coach.invites.createTimeLimited")
  static let optionalLabel = CoachLocalization.localized("coach.invites.optionalLabel")
  static let labelPlaceholder = CoachLocalization.localized("coach.invites.labelPlaceholder")
  static let generate = CoachLocalization.localized("coach.invites.generate")
  static let validity = CoachLocalization.localized("coach.invites.validity")
  static let sevenDays = CoachLocalization.localized("coach.invites.sevenDays")
  static let thirtyDays = CoachLocalization.localized("coach.invites.thirtyDays")
  static let custom = CoachLocalization.localized("coach.invites.custom")
  static let operationFailed = CoachLocalization.localized("coach.invites.operationFailed")

  static func usedCount(_ count: Int) -> String {
    CoachLocalization.localized("coach.invites.usedCount \(count)")
  }

  static func days(_ count: Int) -> String {
    CoachLocalization.localized("coach.invites.days \(count)")
  }

  static let statusActive = CoachLocalization.localized("coach.invites.status.active")
  static let statusUsed = CoachLocalization.localized("coach.invites.status.used")
  static let statusExpired = CoachLocalization.localized("coach.invites.status.expired")
  static let statusRevoked = CoachLocalization.localized("coach.invites.status.revoked")

  static func expiresIn(_ count: Int) -> String {
    CoachLocalization.localized("coach.invites.status.expiresIn \(count)")
  }
}
