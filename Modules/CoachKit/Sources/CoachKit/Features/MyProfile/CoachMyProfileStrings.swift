import Foundation

enum CoachMyProfileStrings {
  struct FrequentlyAskedQuestion: Sendable {
    let question: String
    let answer: String
  }

  static let title = CoachLocalization.localized("coach.profile.title")
  static let fallbackName = CoachLocalization.localized("coach.profile.fallbackName")
  static let permanentInvite = CoachLocalization.localized("coach.profile.permanentInvite")
  static let copy = CoachLocalization.localized("coach.profile.copy")
  static let copied = CoachLocalization.localized("coach.profile.copied")
  static let inviteLoading = CoachLocalization.localized("coach.profile.inviteLoading")
  static let inviteFailed = CoachLocalization.localized("coach.profile.inviteFailed")
  static let inviteEmpty = CoachLocalization.localized("coach.profile.inviteEmpty")
  static let general = CoachLocalization.localized("coach.profile.general")
  static let help = CoachLocalization.localized("coach.profile.help")
  static let helpSubtitle = CoachLocalization.localized("coach.profile.helpSubtitle")
  static let privacyAndTerms = CoachLocalization.localized("coach.profile.privacyAndTerms")
  static let privacyAndTermsSubtitle = CoachLocalization.localized(
    "coach.profile.privacyAndTermsSubtitle"
  )
  static let appVersion = CoachLocalization.localized("coach.profile.appVersion")
  static let internalBeta = CoachLocalization.localized("coach.profile.internalBeta")
  static let logout = CoachLocalization.localized("coach.profile.logout")
  static let loggingOut = CoachLocalization.localized("coach.profile.loggingOut")
  static let contactUs = CoachLocalization.localized("coach.profile.contactUs")
  static let contactHours = CoachLocalization.localized("coach.profile.contactHours")
  static let userAgreement = CoachLocalization.localized("coach.profile.userAgreement")
  static let privacyPolicy = CoachLocalization.localized("coach.profile.privacyPolicy")
  static let documentDate = CoachLocalization.localized("coach.profile.documentDate")
  static let studentDataUsage = CoachLocalization.localized("coach.profile.studentDataUsage")
  static let studentDataDescription = CoachLocalization.localized(
    "coach.profile.studentDataDescription"
  )
  static let logoutTitle = CoachLocalization.localized("coach.profile.logoutTitle")
  static let logoutMessage = CoachLocalization.localized("coach.profile.logoutMessage")
  static let cancel = CoachLocalization.localized("coach.profile.cancel")
  static let confirmLogout = CoachLocalization.localized("coach.profile.confirmLogout")

  static let frequentlyAskedQuestions: [FrequentlyAskedQuestion] = [
    FrequentlyAskedQuestion(
      question: CoachLocalization.localized("coach.profile.faq.join.question"),
      answer: CoachLocalization.localized("coach.profile.faq.join.answer")
    ),
    FrequentlyAskedQuestion(
      question: CoachLocalization.localized("coach.profile.faq.feedback.question"),
      answer: CoachLocalization.localized("coach.profile.faq.feedback.answer")
    ),
    FrequentlyAskedQuestion(
      question: CoachLocalization.localized("coach.profile.faq.video.question"),
      answer: CoachLocalization.localized("coach.profile.faq.video.answer")
    ),
    FrequentlyAskedQuestion(
      question: CoachLocalization.localized("coach.profile.faq.unbind.question"),
      answer: CoachLocalization.localized("coach.profile.faq.unbind.answer")
    ),
  ]

  static func inviteUsage(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.profile.inviteUsage",
      values: ["count": count.formatted()]
    )
  }

  static func appVersionValue(_ version: String) -> String {
    CoachLocalization.replacing(
      "coach.profile.appVersionValue",
      values: ["version": version, "channel": internalBeta]
    )
  }
}
