import DesignSystem
import SwiftUI

/// Hosted outside the tab inset so neither the tab rail nor rest controls cover the pad.
struct WorkoutKeypadOverlay: View {
  let session: WorkoutKeypadSession
  @AccessibilityFocusState private var focusedCell: WorkoutKeypadCell.Address?

  var body: some View {
    if let cell = session.current {
      ZStack(alignment: .bottom) {
        Button(action: session.dismiss) {
          Color.black.opacity(0.2).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
        .accessibilityIdentifier("workout.keypad.dismiss")
        .ignoresSafeArea()

        MeetPRNumberPad(
          field: cell.field, text: cell.value, contextText: cell.context, unit: cell.unit,
          commitTitle: session.next.map {
            StudentStrings.replacing(.keypadNext, values: [$0.fieldTitle])
          },
          onTextCommit: session.commit,
          onCancel: session.dismiss,
          onTextChange: session.update, dismissTitle: StudentStrings.localized(.allDayDone)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cell.context)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { session.dismiss() }
        .accessibilityFocused($focusedCell, equals: cell.id)
        .onAppear { focusedCell = cell.id }
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
