import SwiftUI

extension Color.MeetPR {
  public static let completedVideoPlay = Color(
    light: Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255),
    dark: Color(red: 107 / 255, green: 107 / 255, blue: 114 / 255)
  )
  public static let completedVideoReviewFill = Color(
    red: 17 / 255, green: 24 / 255, blue: 39 / 255
  ).opacity(0.72)
  public static let completedVideoReviewBorder = Color.white.opacity(0.18)
  public static let completedVideoCloseFill = Color.black.opacity(0.45)

  /// Coach video-workbench playback stage fill (RGB 27/37/52).
  public static let videoStageFill = Color(
    red: 27 / 255,
    green: 37 / 255,
    blue: 52 / 255
  )

  /// Coach video-workbench stage border and progress track (RGB 42/54/70).
  public static let videoStageBorder = Color(
    red: 42 / 255,
    green: 54 / 255,
    blue: 70 / 255
  )
}
