import Foundation

enum StudentStrings {
  static let notifications = localized("student.notifications")
  static let notificationsUnread = localized("student.notificationsUnread")
  static let coachMessages = localized("student.coachMessages")
  static let myCoach = localized("student.myCoach")
  static let startCoachConversation = localized("student.startCoachConversation")
  static let unreadSuffix = localized("student.unreadSuffix")
  static let acknowledge = localized("student.acknowledge")
  static let askCoach = localized("student.askCoach")
  static let trainingShareConversationFailed = localized(
    "student.trainingShareConversationFailed"
  )
  static let trainingShareFailed = localized("student.trainingShareFailed")

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
