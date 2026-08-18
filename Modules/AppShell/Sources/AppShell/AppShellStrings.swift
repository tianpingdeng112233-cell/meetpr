import Foundation

enum AppShellStrings {
  static let phoneNumber = localized("appShell.auth.phoneNumber")
  static let password = localized("appShell.auth.password")
  static let phoneInputHint = localized("appShell.auth.phoneInputHint")
  static let passwordInputHint = localized("appShell.auth.passwordInputHint")
  static let hidePassword = localized("appShell.auth.hidePassword")
  static let showPassword = localized("appShell.auth.showPassword")
  static let phoneHelper = localized("appShell.auth.phoneHelper")
  static let invalidPhone = localized("appShell.auth.invalidPhone")
  static let invalidPassword = localized("appShell.auth.invalidPassword")
  static let networkUnstable = localized("appShell.auth.networkUnstable")
  static let phoneTaken = localized("appShell.auth.phoneTaken")
  static let invalidCredentials = localized("appShell.auth.invalidCredentials")
  static let invalidPhoneWithPrefix = localized("appShell.auth.invalidPhoneWithPrefix")
  static let rateLimited = localized("appShell.auth.rateLimited")
  static let requestFailed = localized("appShell.auth.requestFailed")
  static let loginInstructions = localized("appShell.login.instructions")
  static let signIn = localized("appShell.login.signIn")
  static let consent = localized("appShell.login.consent")
  static let privacyPolicy = localized("appShell.privacy.policy")
  static let signupEyebrow = localized("appShell.signup.eyebrow")
  static let signupTitle = localized("appShell.signup.title")
  static let roleLocked = localized("appShell.signup.roleLocked")
  static let multiRoleLater = localized("appShell.signup.multiRoleLater")
  static let passwordMinimum = localized("appShell.signup.passwordMinimum")
  static let passwordMaximum = localized("appShell.signup.passwordMaximum")
  static let signUp = localized("appShell.signup.signUp")
  static let coach = localized("appShell.signup.role.coach")
  static let coachedStudent = localized("appShell.signup.role.coachedStudent")
  static let selfTrainingStudent = localized("appShell.signup.role.selfTrainingStudent")
  static let coachRoleDescription = localized("appShell.signup.role.coach.description")
  static let coachedStudentRoleDescription = localized(
    "appShell.signup.role.coachedStudent.description"
  )
  static let selfTrainingRoleDescription = localized(
    "appShell.signup.role.selfTrainingStudent.description"
  )
  static let analyticsPrivacyTitle = localized("appShell.privacy.analytics.title")
  static let analyticsPrivacyBody = localized("appShell.privacy.analytics.body")
  static let acknowledge = localized("appShell.acknowledge")
  static let validatingSession = localized("appShell.root.validatingSession")
  static let demoCoach = localized("appShell.demo.coach")
  static let demoStudent = localized("appShell.demo.student")

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
