import SwiftUI

/// All-day callers supply row operations; other number-pad presentations keep their own actions.
@MainActor
public struct MeetPRAllDayPadActions {
  let effortField: MeetPRNumberPad.Field
  let canAdd: Bool
  let onAdd: () -> Void
  let onFillUp: () -> Void
  let onFillDown: () -> Void
  let onEffort: () -> Void

  public init(
    effortField: MeetPRNumberPad.Field, canAdd: Bool = true,
    onAdd: @escaping () -> Void, onFillUp: @escaping () -> Void,
    onFillDown: @escaping () -> Void, onEffort: @escaping () -> Void
  ) {
    self.effortField = effortField
    self.canAdd = canAdd
    self.onAdd = onAdd
    self.onFillUp = onFillUp
    self.onFillDown = onFillDown
    self.onEffort = onEffort
  }
}
