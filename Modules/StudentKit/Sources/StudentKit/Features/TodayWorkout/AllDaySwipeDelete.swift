import CoreGraphics
import DesignSystem
import SwiftUI

/// Swipe-left-to-reveal "Delete" for student-owned set rows (spec 112 iOS follow-up).
/// The swipe only reveals the button; deleting still goes through the row's confirmation.
enum AllDaySwipeDelete {
  static let revealWidth: CGFloat = 76

  /// How a tap on one of the row's cells should be treated.
  enum TapState: Equatable {
    /// No swipe involved: the tap edits the cell.
    case idle
    /// A swipe is moving or just ended: the tap is the tail of the drag and is ignored.
    case dragging
    /// The row rests open: a tap closes it instead of editing.
    case open
  }

  static func canSwipe(isRemovableRow: Bool, editable: Bool, editing: Bool) -> Bool {
    isRemovableRow && editable && !editing
  }

  /// Live row offset for a drag, or nil when the drag is vertical and belongs to the scroll view.
  static func offset(open: Bool, translation: CGSize) -> CGFloat? {
    guard isHorizontal(translation) else { return nil }
    let base: CGFloat = open ? -revealWidth : 0
    return min(0, max(-revealWidth * 1.2, base + translation.width))
  }

  /// Whether the row rests open after the finger lifts.
  static func settlesOpen(open: Bool, translation: CGSize) -> Bool {
    guard isHorizontal(translation) else { return open }
    let base: CGFloat = open ? -revealWidth : 0
    return base + translation.width < -revealWidth / 2
  }

  private static func isHorizontal(_ translation: CGSize) -> Bool {
    abs(translation.width) > abs(translation.height)
  }
}

struct AllDaySwipeDeleteModifier: ViewModifier {
  let enabled: Bool
  let rowID: UUID
  /// Lets the row's cell buttons ignore the tail of a swipe and close an open row on tap,
  /// so a swipe that starts on a cell never opens the keypad.
  @Binding var tapState: AllDaySwipeDelete.TapState
  /// Toggled by the row when a cell is tapped while open; closes the row.
  let closeRequest: Int
  let onDelete: () -> Void
  @State private var open = false
  @State private var offset: CGFloat = 0
  @State private var releaseTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    ZStack(alignment: .trailing) {
      if offset < 0 {
        Button {
          close()
          onDelete()
        } label: {
          Text(StudentStrings.localized(.addedDeleteAction))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: AllDaySwipeDelete.revealWidth)
            .frame(maxHeight: .infinity)
            .background(Color.MeetPR.danger)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("allDay.swipeDelete.\(rowID)")
      }
      content
        .offset(x: offset)
        .simultaneousGesture(
          DragGesture(minimumDistance: 16)
            .onChanged { value in
              if let next = AllDaySwipeDelete.offset(open: open, translation: value.translation) {
                releaseTask?.cancel()
                tapState = .dragging
                offset = next
              }
            }
            .onEnded { value in
              open = AllDaySwipeDelete.settlesOpen(open: open, translation: value.translation)
              withAnimation(.snappy(duration: 0.2)) {
                offset = open ? -AllDaySwipeDelete.revealWidth : 0
              }
              releaseTapsSoon()
            },
          including: enabled ? .all : .subviews
        )
    }
    .onChange(of: enabled) { _, isEnabled in
      if !isEnabled { close() }
    }
    .onChange(of: closeRequest) { close() }
  }

  private func close() {
    open = false
    withAnimation(.snappy(duration: 0.2)) { offset = 0 }
    releaseTapsSoon()
  }

  /// The cell button's tap lands right as the drag ends, so taps count as part of the drag
  /// a moment longer before settling to open or idle.
  private func releaseTapsSoon() {
    releaseTask?.cancel()
    releaseTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      tapState = open ? .open : .idle
    }
  }
}
