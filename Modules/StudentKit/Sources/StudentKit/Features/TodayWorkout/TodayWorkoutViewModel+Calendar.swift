import CoreModels
import Foundation

// Calendar/plan-context derivations, split out of the class body to keep
// TodayWorkoutViewModel.swift inside SwiftLint's file_length budget (same
// precedent as TodayWorkoutTypes.swift).

@available(iOS 17.0, macOS 14.0, *)
extension TodayWorkoutViewModel {
  static func planContext(
    from plan: StudentPlanView?,
    selectedDate: Date
  ) -> TodayWorkoutPlanContext? {
    guard let plan else { return nil }
    return TodayWorkoutPlanContext(
      planKind: plan.planKind,
      weekIndex: weekIndex(for: selectedDate, startDate: plan.startDate, fallback: plan.weekIndex),
      startDate: plan.startDate,
      blockType: plan.blockType,
      mesocyclePhase: plan.mesocyclePhase,
      trainingMax: plan.trainingMax,
      tmSetAt: plan.tmSetAt
    )
  }

  static func weekIndex(for date: Date, startDate: Date, fallback: Int) -> Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: startDate)
    let selected = calendar.startOfDay(for: date)
    guard let elapsedDays = calendar.dateComponents([.day], from: start, to: selected).day else {
      return fallback
    }
    return max(1, elapsedDays / 7 + 1)
  }

  static func dayRange(containing date: Date) -> ClosedRange<Date> {
    let start = Calendar.current.startOfDay(for: date)
    return start...start.addingTimeInterval(86_400 - 1)
  }
}
