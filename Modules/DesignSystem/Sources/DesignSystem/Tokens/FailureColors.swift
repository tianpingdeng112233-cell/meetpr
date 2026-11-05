import SwiftUI

extension Color.MeetPR {
  public static let failure = Color(light: failureLight, dark: failureDark)
  public static let failureSoft = Color(
    light: failureLight.opacity(0.10), dark: failureDark.opacity(0.14))

  private static let failureLight = Color(red: 194 / 255.0, green: 65 / 255.0, blue: 12 / 255.0)
  private static let failureDark = Color(red: 240 / 255.0, green: 149 / 255.0, blue: 74 / 255.0)
}
