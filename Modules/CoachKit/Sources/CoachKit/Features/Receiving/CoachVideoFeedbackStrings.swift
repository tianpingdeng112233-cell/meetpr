import CoreModels
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
  static let addMarker = CoachLocalization.localized("coach.videoFeedback.addMarker")
  static let cancel = CoachLocalization.localized("coach.videoFeedback.cancel")
  static let deleteMarker = CoachLocalization.localized("coach.videoFeedback.deleteMarker")
  static let marker = CoachLocalization.localized("coach.videoFeedback.marker")
  static let markerNote = CoachLocalization.localized("coach.videoFeedback.markerNote")
  static let markerTime = CoachLocalization.localized("coach.videoFeedback.markerTime")
  static let save = CoachLocalization.localized("coach.videoFeedback.save")
  static let markersLoadFailed = CoachLocalization.localized(
    "coach.videoFeedback.markersLoadFailed")
  static let setInfoLoadFailed = CoachLocalization.localized(
    "coach.videoFeedback.setInfoLoadFailed")
  static let setInfoUnavailable = CoachLocalization.localized(
    "coach.videoFeedback.setInfoUnavailable")
  static let markerSaveFailed = CoachLocalization.localized(
    "coach.videoFeedback.markerSaveFailed")
  static let markerDeleteFailed = CoachLocalization.localized(
    "coach.videoFeedback.markerDeleteFailed")
  static let emptyFeedback = CoachLocalization.localized("coach.videoFeedback.emptyFeedback")
  static let sentFeedback = CoachLocalization.localized("coach.videoFeedback.sentFeedback")
  static let sendFailed = CoachLocalization.localized("coach.videoFeedback.sendFailed")
  static let noPendingVideos = CoachLocalization.localized("coach.videoFeedback.noPendingVideos")
  static let noPendingVideosSubtitle = CoachLocalization.localized(
    "coach.videoFeedback.noPendingVideosSubtitle")

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
    CoachLocalization.localized("coach.videoFeedback.queuePosition \(index) \(total)")
  }

  static func repsValue(_ reps: Int) -> String {
    CoachLocalization.localized("coach.videoFeedback.repsValue \(reps)")
  }

  static func rowAccessibility(exerciseName: String) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.rowAccessibility",
      values: ["exercise": exerciseName]
    )
  }

  static func setNumber(_ number: Int) -> String {
    CoachLocalization.localized("coach.videoFeedback.setNumber \(number)")
  }

  static func sizeMegabytes(_ size: String) -> String {
    CoachLocalization.replacing(
      "coach.videoFeedback.sizeMegabytes",
      values: ["size": size]
    )
  }

  static func markerCount(_ count: Int) -> String {
    CoachLocalization.localized("coach.videoFeedback.markerCount \(count)")
  }

}
