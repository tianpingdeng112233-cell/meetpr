import CoreModels
import Foundation

enum TodayWorkoutSelectionResolver {
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
