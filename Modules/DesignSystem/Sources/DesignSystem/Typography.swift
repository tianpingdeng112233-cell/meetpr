import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct MeetPRFont: Sendable {
  public let font: Font

  public init(font: Font) {
    self.font = font
  }

  public static let title = MeetPRFont(font: .title)
  public static let body = MeetPRFont(font: .body)
}
