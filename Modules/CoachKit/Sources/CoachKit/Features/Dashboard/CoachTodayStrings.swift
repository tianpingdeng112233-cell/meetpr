import Foundation

enum CoachTodayStrings {
  static let todo = CoachLocalization.localized("coach.today.todo")
  static let orderedByHandling = CoachLocalization.localized("coach.today.orderedByHandling")
  static let awaitingFeedback = CoachLocalization.localized("coach.today.awaitingFeedback")
  static let unread = CoachLocalization.localized("coach.today.unread")
  static let needsAttention = CoachLocalization.localized("coach.today.needsAttention")
  static let newApplication = CoachLocalization.localized("coach.today.newApplication")
  static let askHowThingsAreGoing = CoachLocalization.localized("coach.today.askHowThingsAreGoing")
  static let allDone = CoachLocalization.localized("coach.today.allDone")
  static let allDoneSubtitle = CoachLocalization.localized("coach.today.allDoneSubtitle")
  static let weekOverview = CoachLocalization.localized("coach.today.weekOverview")
  static let activeAsPlanned = CoachLocalization.localized("coach.today.activeAsPlanned")
  static let notStarted = CoachLocalization.localized("coach.today.notStarted")
  static let noTrainingDaysThisWeek = CoachLocalization.localized(
    "coach.today.noTrainingDaysThisWeek"
  )
  static let viewAllStudents = CoachLocalization.localized("coach.today.viewAllStudents")

  static func pendingVideosTitle(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.today.pendingVideosTitle",
      values: ["count": count.formatted()]
    )
  }

  static func earliestVideoSubtitle(_ relativeTime: String) -> String {
    CoachLocalization.replacing("coach.today.earliestVideoSubtitle", values: ["time": relativeTime])
  }

  static func unreadMessagesTitle(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.today.unreadMessagesTitle",
      values: ["count": count.formatted()]
    )
  }

  static func notTrainedTitle(studentName: String, daysMissed: Int) -> String {
    CoachLocalization.replacing(
      "coach.today.notTrainedTitle",
      values: ["name": studentName, "days": daysMissed.formatted()]
    )
  }

  static func singleApplicationTitle(_ name: String) -> String {
    CoachLocalization.replacing("coach.today.singleApplicationTitle", values: ["name": name])
  }

  static func multipleApplicationsTitle(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.today.multipleApplicationsTitle",
      values: ["count": count.formatted()]
    )
  }

  static func earliestApplicationSubtitle(_ waitingText: String) -> String {
    CoachLocalization.replacing(
      "coach.today.earliestApplicationSubtitle",
      values: ["waiting": waitingText]
    )
  }

  static func acceptedStudent(_ name: String) -> String {
    CoachLocalization.replacing("coach.today.acceptedStudent", values: ["name": name])
  }

  static func trainingDaysCompleted(completed: Int, planned: Int) -> String {
    CoachLocalization.replacing(
      "coach.today.trainingDaysCompleted",
      values: ["completed": completed.formatted(), "planned": planned.formatted()]
    )
  }

  static func peopleCount(_ count: Int) -> String {
    CoachLocalization.replacing("coach.today.peopleCount", values: ["count": count.formatted()])
  }

}
