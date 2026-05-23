import CoreModels
import Foundation

enum StudentFormatting {
  static let dayMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日"
    return formatter
  }()

  static let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "EEEE"
    return formatter
  }()

  static func decimal(_ value: Decimal?) -> String {
    guard let value else {
      return "-"
    }
    return NSDecimalNumber(decimal: value).doubleValue.formatted(
      .number.precision(.fractionLength(0...1))
    )
  }

  static func prescribed(_ set: PrescribedSet) -> String {
    let reps = set.reps.map(String.init) ?? set.repsMax.map { "<= \($0)" } ?? "-"
    return "\(decimal(set.weightKg))kg x \(reps)"
  }

  static func completedCount(
    for day: StudentPlanDay,
    logs: [StudentSetLog]
  ) -> (completed: Int, total: Int) {
    let total = day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    let planExerciseIDs = Set(day.exercises.map(\.id))
    let completed = logs.filter {
      planExerciseIDs.contains($0.planExerciseID) && $0.completed
    }.count
    return (completed, total)
  }
}
