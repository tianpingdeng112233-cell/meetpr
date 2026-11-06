import DesignSystem
import SwiftUI

struct WorkoutKeypadScrollAvoidance: ViewModifier {
  @Environment(WorkoutKeypadSession.self) private var keypad: WorkoutKeypadSession?
  @State private var scrollBottom: CGFloat = 0

  private struct ScrollRequest: Equatable {
    let cell: WorkoutKeypadCell.Address?
    let panelTop: CGFloat
    let scrollBottom: CGFloat
  }

  func body(content: Content) -> some View {
    ScrollViewReader { proxy in
      content
        .safeAreaInset(edge: .bottom, spacing: 0) {
          if keypad?.current != nil, let top = keypad?.panelTop, top > 0 {
            Color.clear.frame(height: max(0, scrollBottom - top + MeetPRSpacing.space3))
          }
        }
        .onGeometryChange(for: CGFloat.self) {
          $0.frame(in: .global).maxY
        } action: {
          scrollBottom = $0
        }
        .task(
          id: ScrollRequest(
            cell: keypad?.current?.id, panelTop: keypad?.panelTop ?? 0, scrollBottom: scrollBottom)
        ) {
          guard let current = keypad?.current, (keypad?.panelTop ?? 0) > 0 else { return }
          await Task.yield()
          guard !Task.isCancelled else { return }
          proxy.scrollTo(current.rowID, anchor: .bottom)
        }
    }
    .onDisappear { keypad?.cancel() }
  }
}
