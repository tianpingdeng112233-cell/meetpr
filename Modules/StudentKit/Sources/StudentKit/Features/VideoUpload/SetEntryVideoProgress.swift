import DesignSystem
import SwiftUI

/// A small visible thumb inside a full-height, accessible scrubbing target.
struct SetEntryVideoProgress: View {
  let playback: SetEntryVideoPlayer

  var body: some View {
    GeometryReader { geometry in
      let thumb = MeetPRSpacing.point10
      let width = max(0, geometry.size.width - thumb)
      let fraction =
        playback.state.duration > 0
        ? playback.state.position / playback.state.duration : 0
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.3))
          .frame(height: MeetPRSpacing.space1)
        Capsule().fill(Color.MeetPR.goldCTA)
          .frame(width: width * fraction + thumb / 2, height: MeetPRSpacing.space1)
        Circle().fill(Color.MeetPR.goldCTA)
          .frame(width: thumb, height: thumb)
          .offset(x: width * fraction)
      }
      .frame(maxHeight: .infinity)
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            guard width > 0, playback.state.duration > 0 else { return }
            let progress = min(max((value.location.x - thumb / 2) / width, 0), 1)
            playback.seek(to: progress * playback.state.duration)
          })
    }
    .frame(minHeight: MeetPRSpacing.minimumHitTarget, maxHeight: MeetPRSpacing.minimumHitTarget)
    .accessibilityElement()
    .accessibilityLabel(StudentStrings.localized(.setEntryVideoProgress))
    .accessibilityValue(
      Duration.seconds(playback.state.position).formatted(.time(pattern: .minuteSecond))
    )
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: playback.seek(to: playback.state.position + 5)
      case .decrement: playback.seek(to: playback.state.position - 5)
      @unknown default: break
      }
    }
    .disabled(playback.state.duration == 0)
  }
}
