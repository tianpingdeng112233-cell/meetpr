import CoreModels
import Foundation

enum TodayWorkoutSelectionResolver {
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
