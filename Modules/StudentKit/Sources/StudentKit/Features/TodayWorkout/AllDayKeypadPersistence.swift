import CoreModels
import DesignSystem
import Foundation

extension TodayWorkoutViewModel {
  /// Direct edits and fill actions enter the same durable save path.
  func updateAllDayValue(
    cell: WorkoutKeypadCell, text: String, dayID: UUID?, unit: UnitPreference
  ) {
    let input = NumberPadTextInput(value: text, field: cell.field)
    guard input.isValid, !text.isEmpty || (cell.field != .reps && cell.field != .weight),
      currentDay?.id == dayID,
      let index = currentDrafts?.firstIndex(where: { $0.id == cell.rowID }),
      let draft = currentDrafts?[index],
      applyAllDayInput(input, draft: draft, index: index, unit: unit)
    else { return }
    Task {
      guard currentDay?.id == dayID,
        let latestIndex = currentDrafts?.firstIndex(where: { $0.id == cell.rowID })
      else { return }
      _ = await saveAllDayRow(rowIndex: latestIndex)
    }
  }

  private func applyAllDayInput(
    _ input: NumberPadTextInput, draft: SetRowDraft, index: Int, unit: UnitPreference
  ) -> Bool {
    switch input.field {
    case .weight:
      let weight = Decimal(string: input.committedText).map {
        unit == .kg ? $0 : UnitDisplay.rounded($0 / UnitDisplay.lbPerKg, scale: 2)
      }
      guard weight != draft.actualWeight else { return false }
      updateWeight(rowIndex: index, weight: weight)
    case .reps:
      let reps = Int(input.committedText)
      guard reps != draft.actualReps else { return false }
      updateReps(rowIndex: index, reps: reps)
    case .rpe, .rir:
      rememberAllDayEffort(input.field == .rir ? .rir : .rpe, for: draft)
      let rpe = input.field == .rpe ? Decimal(string: input.committedText) : nil
      let rir = input.field == .rir ? Int(input.committedText) : nil
      guard rpe != draft.actualRPE || rir != draft.actualRIR else { return false }
      updateEffort(rowIndex: index, rpe: rpe, rir: rir)
    }
    return true
  }
}
