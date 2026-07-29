import CoreModels
import DesignSystem

enum SetDisplayNumber {
  static func number(atOffset offset: Int) -> Int {
    SetIndexDisplay.number(forZeroBasedIndex: offset)
  }

  static func number(for draft: TodayWorkoutSetRowDraft) -> Int {
    number(for: draft.prescribed)
  }

  static func number(for set: PrescribedSet) -> Int {
    SetIndexDisplay.number(forZeroBasedIndex: set.setIndex)
  }
}
