import DesignSystem
import SwiftUI

struct CompletedVideoHitRegion {
  let bounds: Anchor<CGRect>
  let play: () -> Void
}

struct CompletedVideoHitRegions: PreferenceKey {
  static var defaultValue: [Int: CompletedVideoHitRegion] { [:] }

  static func reduce(
    value: inout [Int: CompletedVideoHitRegion], nextValue: () -> [Int: CompletedVideoHitRegion]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

/// Routes pointer taps across overlapping targets without changing row layout.
/// The original Buttons retain their keyboard and accessibility actions.
struct CompletedVideoHitRouting: ViewModifier {
  func body(content: Content) -> some View {
    content.overlayPreferenceValue(CompletedVideoHitRegions.self) { targets in
      GeometryReader { geometry in
        let regions = targets.mapValues { geometry[$0.bounds] }
        Color.clear
          .contentShape(
            Path { path in
              for region in regions.values { path.addRect(region) }
            }
          )
          .onTapGesture { point in
            guard
              let number = TrainingHistoryVideoPresentation.playbackNumber(at: point, in: regions)
            else { return }
            targets[number]?.play()
          }
          .accessibilityHidden(true)
      }
      .padding(-MeetPRSpacing.point22)
    }
  }
}
