import DesignSystem
import SwiftUI

/// Hosted outside the tab inset so neither the tab rail nor rest controls cover the pad.
struct WorkoutKeypadOverlay: View {
  let session: WorkoutKeypadSession

  var body: some View {
    if let cell = session.current {
      ZStack(alignment: .bottom) {
        Button(action: session.cancel) {
          Color.black.opacity(0.2).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StudentStrings.localized(.addedCancel))
        .accessibilityIdentifier("workout.keypad.dismiss")
        .ignoresSafeArea()

        MeetPRNumberPad(
          field: cell.field, text: cell.value, contextText: cell.context, unit: cell.unit,
          commitTitle: session.next.map {
            StudentStrings.replacing(.keypadNext, values: [$0.fieldTitle])
          },
          onTextCommit: session.commit, onCancel: session.cancel
        )
        .id(cell.id)
        .onGeometryChange(for: CGFloat.self) {
          $0.frame(in: .global).minY
        } action: {
          session.panelTop = $0
        }
        .accessibilityIdentifier("workout.keypad")
      }
    }
  }
}
