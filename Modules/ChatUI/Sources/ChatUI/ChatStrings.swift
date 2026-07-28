import Foundation

enum ChatStrings {
  static let messages = localized("chat.messages")
  static let noConversations = localized("chat.noConversations")
  static let image = localized("chat.image")
  static let imageUnavailable = localized("chat.imageUnavailable")
  static let sending = localized("chat.sending")
  static let sendFailed = localized("chat.sendFailed")
  static let retry = localized("chat.retry")
  static let delivered = localized("chat.delivered")
  static let read = localized("chat.read")
  static let composerPlaceholder = localized("chat.composerPlaceholder")
  static let send = localized("chat.send")
  static let choosePhoto = localized("chat.choosePhoto")
  static let close = localized("chat.close")
  static let closePlayback = localized("chat.closePlayback")
  static let loadOlder = localized("chat.loadOlder")
  static let preparingImage = localized("chat.preparingImage")
  static let imagePreparationFailed = localized("chat.imagePreparationFailed")
  static let unread = localized("chat.unread")
  static let trainingShare = localized("chat.trainingShare")
  static let setNumber = localized("chat.setNumber")
  static let load = localized("chat.load")
  static let playVideo = localized("chat.playVideo")
  static let videoPlayback = localized("chat.videoPlayback")
  static let playbackSpeed = localized("chat.playbackSpeed")
  static let playbackFailed = localized("chat.playbackFailed")
  static let refreshing = localized("chat.refreshing")

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
