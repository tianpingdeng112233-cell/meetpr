import SwiftUI

struct GoldCTAHeldGlow: View {
  let cornerRadius: CGFloat
  let layers: [MeetPRShadowToken]

  var body: some View {
    ZStack {
      ForEach(visibleLayers.indices, id: \.self) { index in
        let layer = visibleLayers[index]
        RoundedRectangle(cornerRadius: cornerRadius + layer.spread)
          .inset(by: -layer.spread)
          .stroke(layer.color, lineWidth: layer.spread * 2)
          // CSS blur is twice SwiftUI's shadow/blur radius.
          .blur(radius: layer.swiftUIRadius)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var visibleLayers: [MeetPRShadowToken] {
    layers.filter { !$0.isInset && $0.spread > 1.5 }
  }
}
