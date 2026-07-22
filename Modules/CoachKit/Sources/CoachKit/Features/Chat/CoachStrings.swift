import Foundation

enum CoachStrings {
  static let messages = localized("coach.chat.messages")
  static let sendMessage = localized("coach.chat.sendMessage")
  static let unableToOpenConversation = localized("coach.chat.unableToOpenConversation")
  static let confirmation = localized("coach.chat.ok")

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
