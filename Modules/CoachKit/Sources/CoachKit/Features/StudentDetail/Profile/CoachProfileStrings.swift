import Foundation

enum CoachProfileStrings {
  static let currentOneRM = CoachLocalization.localized("coach.profile.currentOneRM")
  static let edit = CoachLocalization.localized("coach.profile.edit")
  static let editUnavailable = CoachLocalization.localized("coach.profile.editUnavailable")
  static let oneRMExplanation = CoachLocalization.localized("coach.profile.oneRMExplanation")
  static let registrationAnswers = CoachLocalization.localized("coach.profile.registrationAnswers")
  static let basicInfo = CoachLocalization.localized("coach.profile.basicInfo")
  static let weightClass = CoachLocalization.localized("coach.profile.weightClass")
  static let trainingHistory = CoachLocalization.localized("coach.profile.trainingHistory")
  static let trainingEnvironment = CoachLocalization.localized(
    "coach.profile.trainingEnvironment")
  static let targetMeet = CoachLocalization.localized("coach.profile.targetMeet")
  static let focus = CoachLocalization.localized("coach.profile.focus")
  static let injuryHistory = CoachLocalization.localized("coach.profile.injuryHistory")
  static let diet = CoachLocalization.localized("coach.profile.diet")
  static let studentSaid = CoachLocalization.localized("coach.profile.studentSaid")
  static let joinedAt = CoachLocalization.localized("coach.profile.joinedAt")
  static let notProvided = CoachLocalization.localized("coach.profile.notProvided")

  static func age(_ age: Int) -> String {
    CoachLocalization.replacing(
      "coach.profile.age",
      values: ["age": age.formatted()]
    )
  }

  static func weeklyFrequency(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.profile.weeklyFrequency",
      values: ["count": count.formatted()]
    )
  }
}
