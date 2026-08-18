import Foundation

enum CoachImportStrings {
  static let title = localized("coach.import.title")
  static let selectStudent = localized("coach.import.selectStudent")
  static let pickFileDescription = localized("coach.import.pickFileDescription")
  static let selectXLSXFile = localized("coach.import.selectXLSXFile")
  static let review = localized("coach.import.review")
  static let planName = localized("coach.import.planName")
  static let startDate = localized("coach.import.startDate")
  static let incompleteHint = localized("coach.import.incompleteHint")
  static let publishToStudent = localized("coach.import.publishToStudent")
  static let chooseAnotherFile = localized("coach.import.chooseAnotherFile")
  static let noSimilarExercise = localized("coach.import.noSimilarExercise")
  static let publishable = localized("coach.import.publishable")
  static let needsBinding = localized("coach.import.needsBinding")
  static let needsValues = localized("coach.import.needsValues")
  static let needsYourInput = localized("coach.import.needsYourInput")
  static let weightKilograms = localized("coach.import.weightKilograms")
  static let coachNote = localized("coach.import.coachNote")
  static let noTrainingWeeks = localized("coach.import.noTrainingWeeks")

  static func summary(parsed: Int, selected: Int) -> String {
    let key: String.LocalizationValue
    switch (parsed == 1, selected == 1) {
    case (true, true): key = "coach.import.summary.weekSelectedWeek"
    case (true, false): key = "coach.import.summary.weekSelectedWeeks"
    case (false, true): key = "coach.import.summary.weeksSelectedWeek"
    case (false, false): key = "coach.import.summary.weeksSelectedWeeks"
    }
    return replacing(
      key,
      values: ["parsed": parsed.formatted(), "selected": selected.formatted()]
    )
  }

  static func sourceWeek(_ week: Int) -> String {
    CoachLocalization.localized("coach.import.sourceWeek \(week)")
  }

  static func day(_ day: Int) -> String {
    replacing("coach.import.day", values: ["day": day.formatted()])
  }

  static func publishedTo(_ studentName: String) -> String {
    replacing("coach.import.publishedTo", values: ["student": studentName])
  }

  static func boundTo(_ exerciseName: String) -> String {
    replacing("coach.import.boundTo", values: ["exercise": exerciseName])
  }

  static func setNumber(_ number: Int) -> String {
    CoachLocalization.localized("coach.import.setNumber \(number)")
  }

  static func studentLoadFailed(_ message: String) -> String {
    replacing("coach.import.studentLoadFailed", values: ["message": message])
  }

  static func catalogLoadFailed(_ message: String) -> String {
    replacing("coach.import.catalogLoadFailed", values: ["message": message])
  }

  static func parseFailed(_ message: String) -> String {
    replacing("coach.import.parseFailed", values: ["message": message])
  }

  static func publishFailed(_ message: String) -> String {
    replacing("coach.import.publishFailed", values: ["message": message])
  }

  static func defaultPlanName(_ studentName: String) -> String {
    replacing("coach.import.defaultPlanName", values: ["student": studentName])
  }

  private static func localized(_ key: String.LocalizationValue) -> String {
    CoachLocalization.localized(key)
  }

  private static func replacing(
    _ key: String.LocalizationValue,
    values: [String: String]
  ) -> String {
    CoachLocalization.replacing(key, values: values)
  }
}
