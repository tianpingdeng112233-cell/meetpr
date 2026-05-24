import DesignSystem
import SwiftUI

/// MyStrengthBook-style "滑动完成" control: drag the knob across the track to
/// fire `onComplete`. Releasing before the threshold springs the knob back.
@available(iOS 17.0, macOS 14.0, *)
struct SlideToCompleteButton: View {
  let title: String
  let onComplete: () -> Void

  @State private var dragOffset: CGFloat = 0
  private let knobSize: CGFloat = 48
  private let inset: CGFloat = 5

  var body: some View {
    GeometryReader { geo in
      let maxOffset = max(geo.size.width - knobSize - inset * 2, 1)
      let progress = dragOffset / maxOffset

      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.MeetPR.green)

        Text(title)
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .opacity(1 - progress)

        Image(systemName: "chevron.right")
          .font(.title3.bold())
          .foregroundStyle(Color.MeetPR.green)
          .frame(width: knobSize, height: knobSize)
          .background(.white)
          .clipShape(Circle())
          .offset(x: dragOffset + inset)
          .gesture(
            DragGesture()
              .onChanged { value in
                dragOffset = min(max(0, value.translation.width), maxOffset)
              }
              .onEnded { _ in
                if dragOffset >= maxOffset * 0.85 {
                  onComplete()
                }
                withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
              }
          )
      }
    }
    .frame(height: knobSize + inset * 2)
    .accessibilityElement()
    .accessibilityLabel(title)
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { onComplete() }
  }
}
