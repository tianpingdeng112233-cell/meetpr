import CoreModels
import DesignSystem
import Foundation

extension WorkoutKeypadCell {
  static func allDayCells(
    draft: TodayWorkoutSetRowDraft, unit: UnitPreference = .kg,
    effortOverride: MeetPRNumberPad.Field? = nil
  ) -> [Self] {
    let effort = effortOverride ?? (draft.actualRIR == nil ? .rpe : .rir)
    return [
      Self(
        rowID: draft.id, field: .weight,
        value: UnitDisplay.weightText(kg: draft.actualWeight, unit: unit),
        name: draft.displayExerciseName, number: SetDisplayNumber.number(for: draft),
        unit: UnitDisplay.weightUnitSuffix(unit)),
      Self(
        rowID: draft.id, field: .reps, value: draft.actualReps.map(String.init) ?? "",
        name: draft.displayExerciseName, number: SetDisplayNumber.number(for: draft)),
      Self(
        rowID: draft.id, field: effort,
        value: effort == .rir
          ? draft.actualRIR.map(String.init) ?? ""
          : draft.actualRPE.map(SetEntryValue.text) ?? "",
        name: draft.displayExerciseName, number: SetDisplayNumber.number(for: draft)),
    ]
  }
}

extension WorkoutKeypadSession {
  func openAllDay(
    draft: TodayWorkoutSetRowDraft, viewModel: TodayWorkoutViewModel, field: MeetPRNumberPad.Field
  ) {
    if current != nil { dismiss() }
    let dayID = viewModel.currentDay?.id
    let unit = viewModel.onboardingProfile?.unitPreference ?? .kg
    let save: (WorkoutKeypadCell, String) -> Void = { cell, text in
      let input = NumberPadTextInput(value: text, field: cell.field)
      guard input.isValid, !text.isEmpty || cell.field != .reps,
        viewModel.currentDay?.id == dayID,
        let index = viewModel.currentDrafts?.firstIndex(where: { $0.id == draft.id }),
        let current = viewModel.currentDrafts?[index]
      else { return }
      switch cell.field {
      case .weight:
        let entered = Decimal(string: input.committedText)
        let weight = entered.map {
          unit == .kg
            ? $0
            : UnitDisplay.rounded($0 / UnitDisplay.lbPerKg, scale: 2)
        }
        guard weight != current.actualWeight else { return }
        viewModel.updateWeight(rowIndex: index, weight: weight)
      case .reps:
        let reps = Int(input.committedText)
        guard reps != current.actualReps else { return }
        viewModel.updateReps(rowIndex: index, reps: reps)
      case .rpe, .rir:
        let rpe = cell.field == .rpe ? Decimal(string: input.committedText) : nil
        let rir = cell.field == .rir ? Int(input.committedText) : nil
        guard rpe != current.actualRPE || rir != current.actualRIR else { return }
        viewModel.updateEffort(rowIndex: index, rpe: rpe, rir: rir)
      }
      Task {
        guard viewModel.currentDay?.id == dayID,
          let latestIndex = viewModel.currentDrafts?.firstIndex(where: { $0.id == draft.id })
        else { return }
        _ = await viewModel.saveAllDayRow(rowIndex: latestIndex)
      }
    }
    open(
      cells: WorkoutKeypadCell.allDayCells(
        draft: draft, unit: unit, effortOverride: field == .rir || field == .rpe ? field : nil),
      at: .init(rowID: draft.id, field: field),
      onChange: { cell, text in if let text { save(cell, text) } },
      allowsEmptyWeight: true, onCommit: save)
  }
}
