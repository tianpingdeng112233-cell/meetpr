import Foundation

enum CoachRosterStrings {
  static let searchStudents = CoachLocalization.localized("coach.roster.searchStudents")
  static let clearSearch = CoachLocalization.localized("coach.roster.clearSearch")
  static let accept = CoachLocalization.localized("coach.roster.accept")
  static let viewProfile = CoachLocalization.localized("coach.roster.viewProfile")
  static let reject = CoachLocalization.localized("coach.roster.reject")
  static let cancel = CoachLocalization.localized("coach.roster.cancel")
  static let confirmation = CoachLocalization.localized("coach.chat.ok")
  static let completionRate = CoachLocalization.localized("coach.roster.completionRate")
  static let noPlan = CoachLocalization.localized("coach.roster.noPlan")
  static let noTrainingRecords = CoachLocalization.localized("coach.roster.noTrainingRecords")
  static let loadFailed = CoachLocalization.localized("coach.roster.loadFailed")
  static let rejectConfirmation = CoachLocalization.localized("coach.roster.rejectConfirmation")

  static func weekProgress(completed: Int, planned: Int) -> String {
    CoachLocalization.replacing(
      "coach.roster.weekProgress",
      values: ["completed": completed.formatted(), "planned": planned.formatted()]
    )
  }

  static func notTrainedReason(_ daysMissed: Int) -> String {
    CoachLocalization.replacing(
      "coach.roster.notTrainedReason",
      values: ["days": daysMissed.formatted()]
    )
  }

  static func waitingForReplyReason() -> String {
    CoachLocalization.localized("coach.roster.waitingForReplyReason")
  }

  static func newStudentRequests(_ count: Int) -> String {
    sectionCount(
      title: CoachLocalization.localized("coach.roster.newStudentRequests"),
      count: count
    )
  }

  static func activeStudents(_ count: Int) -> String {
    sectionCount(title: CoachLocalization.localized("coach.roster.active"), count: count)
  }

  static func abnormalStudents(_ count: Int) -> String {
    sectionCount(title: CoachLocalization.localized("coach.roster.abnormal"), count: count)
  }

  private static func sectionCount(title: String, count: Int) -> String {
    CoachLocalization.replacing(
      "coach.roster.sectionCount",
      values: ["title": title, "count": count.formatted()]
    )
  }

}
