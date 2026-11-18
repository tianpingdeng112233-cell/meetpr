import CoreModels
import DesignSystem
import Foundation

extension WorkoutKeypadCell {
  static func allDayCells(
    draft: TodayWorkoutSetRowDraft, unit: UnitPreference = .kg,
    effortOverride: MeetPRNumberPad.Field? = nil
  ) -> [Self] {
    let effort = effortOverride ?? (draft.allDayEffortMode() == .rir ? .rir : .rpe)
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
    guard !viewModel.isPreviewingPlan, !viewModel.browsingPastPlan,
      let day = viewModel.currentDay, FlexibleTrainingDay.canWrite(day, in: viewModel.planDays)
    else { return }
    let previousEffort =
      effortField(for: draft.id)
      ?? (draft.allDayEffortMode(previous: viewModel.previousAllDayEffort(for: draft)) == .rir
        ? .rir : .rpe)
    if current != nil { dismiss() }
    guard let draft = viewModel.currentDrafts?.first(where: { $0.id == draft.id }) else { return }
    let dayID = viewModel.currentDay?.id
    let unit = viewModel.onboardingProfile?.unitPreference ?? .kg
    let save: (WorkoutKeypadCell, String) -> Void = { cell, text in
      viewModel.updateAllDayValue(cell: cell, text: text, dayID: dayID, unit: unit)
    }
    let cells = WorkoutKeypadCell.allDayCells(
      draft: draft, unit: unit,
      effortOverride: field == .rir || field == .rpe ? field : previousEffort
    ).map { original in
      var cell = original
      cell.number = viewModel.allDayDisplayNumber(for: draft)
      cell.isWarmup = draft.isWarmup
      return cell
    }
    open(
      cells: cells,
      at: .init(rowID: draft.id, field: field),
      onChange: { cell, text in if let text { save(cell, text) } },
      allowsEmptyWeight: false, allowsBackgroundInteraction: true, onCommit: save)
    configureAllDayActions(draft: draft, viewModel: viewModel)

  }
}
