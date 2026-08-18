import CoreModels
import Foundation

enum StudentExerciseName {
  static func display(_ exercise: Exercise, locale: Locale = .current) -> String {
    guard locale.language.languageCode?.identifier == "en",
      let nameEn = exercise.nameEn?.trimmingCharacters(in: .whitespacesAndNewlines),
      !nameEn.isEmpty
    else {
      return exercise.name
    }
    return nameEn
  }

  static func display(
    _ video: CoachFeedbackVideo,
    locale: Locale = .current
  ) -> String? {
    guard locale.language.languageCode?.identifier == "en",
      let nameEn = video.exerciseNameEn?.trimmingCharacters(in: .whitespacesAndNewlines),
      !nameEn.isEmpty
    else {
      return video.exerciseName
    }
    return nameEn
  }
}
