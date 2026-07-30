import Foundation

enum CoachVideoFeedbackStrings {
  static let back = CoachLocalization.localized("coach.videoFeedback.back")
  static let loading = CoachLocalization.localized("coach.videoFeedback.loading")
  static let kilograms = CoachLocalization.localized("coach.videoFeedback.kilograms")
  static let missingValue = CoachLocalization.localized("coach.videoFeedback.missingValue")
  static let playFailed = CoachLocalization.localized("coach.videoFeedback.playFailed")
  static let retry = CoachLocalization.localized("coach.videoFeedback.retry")
  static let rpe = CoachLocalization.localized("coach.videoFeedback.rpe")
  static let send = CoachLocalization.localized("coach.videoFeedback.send")
  static let setOrder = CoachLocalization.localized("coach.videoFeedback.setOrder")
  static let skip = CoachLocalization.localized("coach.videoFeedback.skip")
  static let trainingVideo = CoachLocalization.localized("coach.videoFeedback.trainingVideo")
  static let reps = CoachLocalization.localized("coach.videoFeedback.reps")
  static let weight = CoachLocalization.localized("coach.videoFeedback.weight")

  static func feedbackPlaceholder(studentName: String) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.feedbackPlaceholder",
      values: ["name": studentName]
    )
  }

  static func title(studentName: String, exerciseName: String) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.title",
      values: [
        "student": studentName,
        "exercise": exerciseName,
      ]
    )
  }

  static func headerMeta(setText: String, relativeTime: String) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.headerMeta",
      values: [
        "set": setText,
        "relativeTime": relativeTime,
      ]
    )
  }

  static func queuePosition(index: Int, total: Int) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.queuePosition",
      values: [
        "index": index.formatted(),
        "total": total.formatted(),
      ]
    )
  }

  static func repsValue(_ reps: Int) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.repsValue",
      values: ["reps": reps.formatted()]
    )
  }

  static func rowAccessibility(exerciseName: String) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.rowAccessibility",
      values: ["exercise": exerciseName]
    )
  }

  static func setNumber(_ number: Int) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.setNumber",
      values: ["number": number.formatted()]
    )
  }

  static func sizeMegabytes(_ size: String) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.sizeMegabytes",
      values: ["size": size]
    )
  }
}
