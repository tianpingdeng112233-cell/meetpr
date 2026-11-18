import Foundation

#if canImport(UIKit)
  import AudioToolbox
  import UIKit
#endif

@MainActor
enum RestRingFeedback {
  #if canImport(UIKit)
    private static var soundID: SystemSoundID = 0
  #endif

  static func emit(_ alert: RestRingModel.Alert) {
    #if canImport(UIKit)
      if alert.vibrate { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
      if alert.sound {
        if soundID == 0,
          let url = Bundle.module.url(forResource: "rest-finished", withExtension: "wav")
        {
          AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        }
        if soundID != 0 { AudioServicesPlaySystemSound(soundID) }
      }
    #endif
  }

  static func hold() {
    #if canImport(UIKit)
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
  }
}
