import Foundation

enum CoachDetailStrings {
  static let backToStudents = CoachLocalization.localized("coach.detail.backToStudents")
  static let remindTraining = CoachLocalization.localized("coach.detail.remindTraining")
  static let weekSummary = CoachLocalization.localized("coach.detail.weekSummary")
  static let weekTraining = CoachLocalization.localized("coach.detail.weekTraining")
  static let tapDayForDetails = CoachLocalization.localized("coach.detail.tapDayForDetails")
  static let noTrainingThisWeek = CoachLocalization.localized("coach.detail.noTrainingThisWeek")
  static let adjusted = CoachLocalization.localized("coach.detail.adjusted")
  static let todayStatus = CoachLocalization.localized("coach.detail.todayStatus")
  static let todayNotFiled = CoachLocalization.localized("coach.detail.todayNotFiled")
  static let remindToFile = CoachLocalization.localized("coach.detail.remindToFile")
  static let statusUnavailable = CoachLocalization.localized("coach.detail.statusUnavailable")
  static let recentFeedback = CoachLocalization.localized("coach.detail.recentFeedback")
  static let noFeedback = CoachLocalization.localized("coach.detail.noFeedback")
  static let writeFirstFeedback = CoachLocalization.localized("coach.detail.writeFirstFeedback")
  static let training = CoachLocalization.localized("coach.detail.training")
  static let completed = CoachLocalization.localized("coach.detail.completed")
  static let today = CoachLocalization.localized("coach.detail.today")
  static let notStarted = CoachLocalization.localized("coach.detail.notStarted")
  static let loading = CoachLocalization.localized("coach.detail.loading")
  static let loadFailed = CoachLocalization.localized("coach.detail.loadFailed")
  static let noPlan = CoachLocalization.localized("coach.detail.noPlan")
  static let noPlanSubtitle = CoachLocalization.localized("coach.detail.noPlanSubtitle")
  static let planLoadFailed = CoachLocalization.localized("coach.detail.planLoadFailed")
  static let pullToRetry = CoachLocalization.localized("coach.detail.pullToRetry")
  static let trainingReminderDraft = CoachLocalization.localized(
    "coach.detail.trainingReminderDraft")
  static let readinessReminderDraft = CoachLocalization.localized(
    "coach.detail.readinessReminderDraft")
  static let profileUnavailable = CoachLocalization.localized("coach.detail.profileUnavailable")
  static let active = CoachLocalization.localized("coach.detail.active")
  static let needsAttention = CoachLocalization.localized("coach.detail.needsAttention")
  static let weekSummaryUnavailable = CoachLocalization.localized(
    "coach.detail.weekSummaryUnavailable")
  static let evaluationLoadFailed = CoachLocalization.localized(
    "coach.detail.evaluationLoadFailed")
  static let retry = CoachLocalization.localized("coach.detail.retry")

  static func sectionTitle(_ section: StudentDetailSection) -> String {
    switch section {
    case .overview: CoachLocalization.localized("coach.detail.section.overview")
    case .videos: CoachLocalization.localized("coach.detail.section.videos")
    case .growth: CoachLocalization.localized("coach.detail.section.growth")
    case .feedback: CoachLocalization.localized("coach.detail.section.feedback")
    case .profile: CoachLocalization.localized("coach.detail.section.profile")
    }
  }

  static func weekProgress(completed: Int, total: Int) -> String {
    CoachLocalization.localized("coach.detail.weekProgress \(completed) \(total)")
  }

  static func feedbackMeta(relativeTime: String) -> String {
    CoachLocalization.replacing(
      "coach.detail.feedbackMeta",
      values: ["relativeTime": relativeTime]
    )
  }

  static func weekRunningTitle(_ week: Int) -> String {
    CoachLocalization.localized("coach.detail.weekRunningTitle \(week)")
  }

  static func evaluationDays(_ days: Int) -> String {
    CoachLocalization.localized("coach.detail.evaluationDays \(days)")
  }

  static func evaluationHours(_ hours: Int) -> String {
    CoachLocalization.localized("coach.detail.evaluationHours \(hours)")
  }

  static func weekday(_ calendarWeekday: Int) -> String {
    switch calendarWeekday {
    case 1: CoachLocalization.localized("coach.detail.weekday.sun")
    case 2: CoachLocalization.localized("coach.detail.weekday.mon")
    case 3: CoachLocalization.localized("coach.detail.weekday.tue")
    case 4: CoachLocalization.localized("coach.detail.weekday.wed")
    case 5: CoachLocalization.localized("coach.detail.weekday.thu")
    case 6: CoachLocalization.localized("coach.detail.weekday.fri")
    default: CoachLocalization.localized("coach.detail.weekday.sat")
    }
  }
}
