import CoreModels
import Foundation

enum TrainingSequenceDayState: Equatable, Sendable {
  case completed
  case current
  case upcoming
}

struct TrainingSequenceDay: Equatable, Identifiable, Sendable {
  let day: StudentPlanDay
  let state: TrainingSequenceDayState
  let isSelected: Bool

  var id: UUID { day.id }
}

struct TrainingSequenceWeek: Equatable, Identifiable, Sendable {
  let weekNumber: Int
  let days: [TrainingSequenceDay]

  var id: Int { weekNumber }
}

enum TrainingSequenceLayout {
  /// The cursor order is defined only by backend spec 035 §术语与排序正典.
  static func makeWeeks(
    days: [StudentPlanDay],
    selectedDayID: UUID?
  ) -> [TrainingSequenceWeek] {
    let sequence = StudentPlanSequence(days: days)
    let cursorID = sequence.cursorDay?.id
    let groups = Dictionary(grouping: sequence.orderedDays, by: \.weekNumber)
    return groups.keys.sorted().map { weekNumber in
      TrainingSequenceWeek(
        weekNumber: weekNumber,
        days: (groups[weekNumber] ?? []).map { day in
          TrainingSequenceDay(
            day: day,
            state: day.completedAt != nil
              ? .completed : (day.id == cursorID ? .current : .upcoming),
            isSelected: day.id == selectedDayID
          )
        }
      )
    }
  }

  static func initialSelection(days: [StudentPlanDay], explicitDayID: UUID?) -> UUID? {
    let sequence = StudentPlanSequence(days: days)
    if let explicitDayID, sequence.orderedDays.contains(where: { $0.id == explicitDayID }) {
      return explicitDayID
    }
    return sequence.cursorDay?.id ?? sequence.orderedDays.last?.id
  }
}

enum TrainingSequenceText {
  static func recommendation(_ date: Date) -> String {
    let calendar = PlanCalendarDayIdentity.utcCalendar
    let components = calendar.dateComponents([.month, .day, .weekday], from: date)
    let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    let weekdayIndex = (components.weekday ?? 1) - 1
    let weekday = weekdays.indices.contains(weekdayIndex) ? weekdays[weekdayIndex] : ""
    return "教练推荐 \(components.month ?? 0)/\(components.day ?? 0) \(weekday)"
  }

  static func dayName(_ day: StudentPlanDay) -> String {
    let families = MainLiftExerciseFamilyResolver.families(in: day)
    guard !families.isEmpty else { return "训练日" }
    return families.map(\.studentDisplayName).joined(separator: " · ")
  }

  static func unlockMessage(after day: StudentPlanDay) -> String {
    "练完 W\(day.weekNumber) · \(DashboardTodayPresentation.dayName(day)) 后自动轮到这一节。"
  }

  static func exerciseSummary(_ day: StudentPlanDay) -> String {
    let sets = day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    return "\(day.exercises.count) 个动作 · \(sets) 组"
  }
}
