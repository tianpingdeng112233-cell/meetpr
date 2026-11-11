import Foundation

enum StudentConversationOpenFailure: String, Identifiable, Sendable {
  case noActiveCoach
  case bindRequired
  case network

  var id: String { rawValue }

  var title: String {
    switch self {
    case .noActiveCoach:
      StudentStrings.localized(.studentNotificationComponents001)
    case .bindRequired:
      StudentStrings.localized(.studentNotificationComponents003)
    case .network:
      StudentStrings.localized(.studentNotificationComponents005)
    }
  }

  var message: String {
    switch self {
    case .noActiveCoach:
      StudentStrings.localized(.studentNotificationComponents002)
    case .bindRequired:
      StudentStrings.localized(.studentNotificationComponents004)
    case .network:
      StudentStrings.localized(.studentNotificationComponents006)
    }
  }
}
