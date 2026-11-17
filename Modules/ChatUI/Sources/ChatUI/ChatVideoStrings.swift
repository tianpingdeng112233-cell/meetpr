import Foundation

public enum ChatVideoStrings {
  public static let video = String(localized: "chat.video.title", bundle: .module)
  public static let preview = String(localized: "chat.video.preview", bundle: .module)
  public static let chooseAgain = String(localized: "chat.video.chooseAgain", bundle: .module)
  public static let cancel = String(localized: "chat.cancel", bundle: .module)
  public static let send = String(localized: "chat.send", bundle: .module)
  public static let preparing = String(localized: "chat.video.preparing", bundle: .module)
  public static let preparationFailed = String(
    localized: "chat.video.preparationFailed", bundle: .module)
  public static let tooLarge = String(localized: "chat.video.tooLarge", bundle: .module)
  public static let unavailable = String(
    localized: "chat.standaloneVideoUnavailable", bundle: .module)
  public static func recipient(_ name: String) -> String {
    String(localized: "chat.video.recipient", bundle: .module).replacing("{name}", with: name)
  }
}
