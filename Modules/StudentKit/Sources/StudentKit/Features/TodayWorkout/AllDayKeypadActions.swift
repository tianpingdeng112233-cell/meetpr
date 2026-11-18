import CoreModels
import DesignSystem
import Foundation

extension WorkoutKeypadSession {
  enum FillDirection { case upward, downward }

  func fillAllDay(_ direction: FillDirection, viewModel: TodayWorkoutViewModel) {
    actionMessage = nil
    guard let cell = current, let text = previewText,
      let source = viewModel.currentDrafts?.first(where: { $0.id == cell.rowID }),
      let group = viewModel.allDaySheet.first(where: { $0.id == source.planExerciseID }),
      NumberPadTextInput(value: text, field: cell.field).isValid,
      !text.isEmpty || cell.field == .rpe || cell.field == .rir
    else { return }
    let targets = group.rows.filter {
      $0.isWarmup == source.isWarmup
        && (direction == .upward
          ? $0.prescribed.setIndex < source.prescribed.setIndex
          : $0.prescribed.setIndex > source.prescribed.setIndex)
    }
    for row in targets {
      let target = WorkoutKeypadCell(rowID: row.id, field: cell.field, value: "")
      apply(text, to: target)
    }
    actionMessage =
      targets.isEmpty
      ? StudentStrings.localized(direction == .upward ? .keypadNoRowsUp : .keypadNoRowsDown)
      : StudentStrings.replacing(
        direction == .upward ? .keypadFilledUp : .keypadFilledDown,
        values: [String(targets.count), cell.fieldTitle])
  }

  func addAllDaySet(viewModel: TodayWorkoutViewModel) {
    guard let cell = current,
      let source = viewModel.currentDrafts?.first(where: { $0.id == cell.rowID })
    else { return }
    dismiss()
    let existing = Set((viewModel.currentDrafts ?? []).map(\.id))
    if source.isWarmup {
      viewModel.addWarmupSet(exerciseID: source.planExerciseID)
    } else if source.isStudentAdded {
      viewModel.addStudentSet(exerciseID: source.exerciseID)
    } else {
      viewModel.addExtraSet(exerciseID: source.planExerciseID, copyLastVisible: true)
    }
    let target =
      viewModel.currentDrafts?.first { !existing.contains($0.id) }
      ?? viewModel.currentDrafts?.first { $0.id == source.id }
    if let target { openAllDay(draft: target, viewModel: viewModel, field: .weight) }
  }

  func openAllDayEffort(viewModel: TodayWorkoutViewModel) {
    guard let cell = current,
      let draft = viewModel.currentDrafts?.first(where: { $0.id == cell.rowID })
    else { return }
    let field = effortField(for: cell.rowID) ?? .rpe
    openAllDay(draft: draft, viewModel: viewModel, field: field)
  }

  func configureAllDayActions(draft: TodayWorkoutSetRowDraft, viewModel: TodayWorkoutViewModel) {
    let rows = (viewModel.currentDrafts ?? []).filter { $0.planExerciseID == draft.planExerciseID }
    let count = rows.filter { draft.isWarmup ? $0.isWarmup : $0.isExtra && !$0.isWarmup }.count
    let canAdd =
      draft.isStudentAdded
      ? rows.count < StudentAddedRows.limit
      : count < (draft.isWarmup ? 5 : StudentAddedRows.limit)
    allDayActions = MeetPRAllDayPadActions(
      effortField: effortField(for: draft.id) ?? .rpe, canAdd: canAdd,
      onAdd: { [weak self, weak viewModel] in
        if let viewModel { self?.addAllDaySet(viewModel: viewModel) }
      },
      onFillUp: { [weak self, weak viewModel] in
        if let viewModel { self?.fillAllDay(.upward, viewModel: viewModel) }
      },
      onFillDown: { [weak self, weak viewModel] in
        if let viewModel { self?.fillAllDay(.downward, viewModel: viewModel) }
      },
      onEffort: { [weak self, weak viewModel] in
        if let viewModel { self?.openAllDayEffort(viewModel: viewModel) }
      })
  }
}
