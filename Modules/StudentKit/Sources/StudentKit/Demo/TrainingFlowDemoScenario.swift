import CoreModels
import Foundation

/// Spec 090 acceptance only. The ordinary Demo and the 086/089 flags are unchanged.
enum TrainingFlowDemoScenario {
  static var enabled: Bool {
    ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--spec090-") }
  }
  static var usesPounds: Bool { has("lb") }

  static func configure(_ plan: StudentPlanView) -> StudentPlanView {
    guard enabled, plan.days.count > 3,
      let main = plan.days[2].exercises.first,
      let accessory = plan.days[3].exercises.first(where: { $0.exercise.isAccessory })
    else { return plan }
    let days = plan.days.enumerated().map { index, day in
      guard index == 2 else { return day }
      let templates = [main.exercise, accessory.exercise, accessory.exercise]
      let exercises = templates.enumerated().map { exerciseIndex, exercise in
        StudentPlanExercise(
          id: identifier(10 + exerciseIndex), exercise: exercise, sequenceIndex: exerciseIndex,
          prescribedSets: (0..<(exerciseIndex == 2 ? 2 : 3)).map { setIndex in
            PrescribedSet(
              id: identifier(100 + exerciseIndex * 10 + setIndex), setIndex: setIndex,
              weightKg: exerciseIndex == 0 ? 175 : 60, reps: exerciseIndex == 0 ? 3 : 12, rpe: 8)
          }, notes: main.notes)
      }
      return StudentPlanDay(
        id: day.id, weekNumber: day.weekNumber, dayOfWeek: day.dayOfWeek,
        sortOrder: day.sortOrder, date: day.date, exercises: exercises)
    }
    return StudentPlanView(
      cycleID: plan.cycleID, weekIndex: plan.weekIndex, startDate: plan.startDate,
      endDate: plan.endDate, planKind: plan.planKind, publishedAt: plan.publishedAt, days: days)
  }

  static func logs(plan: StudentPlanView, studentID: UUID) -> [StudentSetLog] {
    plan.days.prefix(3).enumerated().flatMap { dayIndex, day in
      var ordinal = 0
      return day.exercises.enumerated().flatMap { exerciseIndex, exercise in
        exercise.prescribedSets.compactMap { set -> StudentSetLog? in
          let position = ordinal
          ordinal += 1
          let count =
            has("all") ? 8 : has("upgrade") ? 5 : has("main-two") ? 2 : has("main-one") ? 1 : 0
          guard dayIndex < 2 || position < count || (has("skipped") && exerciseIndex == 2)
          else { return nil }
          return StudentSetLog(
            id: set.id, studentID: studentID, planExerciseID: exercise.id,
            exerciseID: exercise.exercise.id, setIndex: set.setIndex,
            loggedAt: day.date.addingTimeInterval(36_000),
            weightKg: set.weightKg ?? 60, reps: set.reps ?? 5, rpe: 8, completed: true)
        }
      }
    }
  }

  private static func has(_ flag: String) -> Bool {
    ProcessInfo.processInfo.arguments.contains("--spec090-\(flag)")
  }

  private static func identifier(_ number: Int) -> UUID {
    let suffix = String(number)
    guard
      let id = UUID(
        uuidString: "09000000-0000-0000-0000-" + String(repeating: "0", count: 12 - suffix.count)
          + suffix)
    else { preconditionFailure("Invalid training flow Demo identifier") }
    return id
  }
}
