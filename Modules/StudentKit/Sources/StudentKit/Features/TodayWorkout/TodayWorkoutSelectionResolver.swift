import CoreModels
import Foundation

enum TodayWorkoutSelectionResolver {
  /// Shares the week strip selection state; preview selection never loads a writable workout.
  static func selectCycleDay(
    _ dayID: UUID, plan: StudentPlanView?, isPreview: Bool,
    selectedDayID: inout UUID?, previewDayID: inout UUID?
  ) {
    guard let plan, plan.days.contains(where: { $0.id == dayID }) else { return }
    if isPreview { previewDayID = dayID } else { selectedDayID = dayID }
  }

  static func receive(
    _ handoff: TodayWorkoutPlanHandoff?, selectedDayID: inout UUID?, days: [StudentPlanDay]
  ) {
    selectedDayID = initialSelection(
      explicitDayID: handoff?.dayID, days: handoff?.plan.days ?? days)
  }

  static func initialSelection(
    explicitDayID: UUID?,
    days: [StudentPlanDay]
  ) -> UUID? {
    TrainingSequenceLayout.initialSelection(days: days, explicitDayID: explicitDayID)
  }

  static func jumpToCurrentSelection(
    from selectedDayID: UUID?,
    days: [StudentPlanDay]
  ) -> UUID? {
    let cursorID = StudentPlanSequence(days: days).cursorDay?.id
    guard cursorID != selectedDayID else { return nil }
    return cursorID
  }
}
