import Foundation

enum StudentStrings {
  static let notifications = localized("student.notifications")
  static let notificationsUnread = localized("student.notificationsUnread")
  static let coachMessages = localized("student.coachMessages")
  static let myCoach = localized("student.myCoach")
  static let startCoachConversation = localized("student.startCoachConversation")
  static let unreadSuffix = localized("student.unreadSuffix")
  static let filterTitle = localized("student.filter.title")
  static let filterAllExercises = localized("student.filter.allExercises")
  static let filterSearchPlaceholder = localized("student.filter.searchPlaceholder")
  static let filterClearSearch = localized("student.filter.clearSearch")
  static let acknowledge = localized("student.acknowledge")
  static let askCoach = localized("student.askCoach")
  static let trainingShareConversationFailed = localized(
    "student.trainingShareConversationFailed"
  )
  static let trainingShareFailed = localized("student.trainingShareFailed")

  static func filterNoMatch(_ query: String) -> String {
    String(localized: "student.filter.noMatch \(query)", bundle: .module)
  }

  static func filterAccessibilityLabel(_ selection: String) -> String {
    String(localized: "student.filter.accessibilityLabel \(selection)", bundle: .module)
  }

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
