import CoreModels
import Foundation

/// Opt-in spec 092 walkthrough. Default and old-user Demo routes keep their original data.
enum StudentAddedDemoScenario {
  static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--spec092-added") }

  static func configure(_ plan: StudentPlanView) -> StudentPlanView {
    guard enabled else { return plan }
    let days = plan.days.enumerated().map { index, day in
      day.replacingCompletion(
        completedAt: index == 0
          ? Date().addingTimeInterval(-86_400)
          : index == 3 ? Date().addingTimeInterval(-60) : nil,
        source: index == 0 || index == 3 ? "manual" : nil)
    }
    return StudentPlanView(
      cycleID: plan.cycleID, weekIndex: plan.weekIndex,
      startDate: plan.startDate, endDate: plan.endDate, planKind: plan.planKind,
      publishedAt: plan.publishedAt, days: days)
  }

  static func logs(plan: StudentPlanView, studentID: UUID) -> [StudentSetLog] {
    guard enabled, plan.days.count > 1, let exercise = plan.days[1].exercises.first else {
      return []
    }
    let entries = Array(exercise.prescribedSets.prefix(2)).map { set in
      StudentSetLog(
        id: set.id, studentID: studentID, planExerciseID: exercise.id,
        exerciseID: exercise.exercise.id, setIndex: set.setIndex, loggedAt: Date(),
        weightKg: set.weightKg ?? 100, reps: set.reps ?? 5, rpe: 8, completed: true)
    }
    return entries + [
      StudentSetLog(
        id: UUID(), studentID: studentID, planExerciseID: exercise.id,
        exerciseID: exercise.exercise.id, setIndex: exercise.prescribedSets.count,
        loggedAt: Date(), weightKg: 90, reps: 3, rpe: 7, completed: true)
    ]
  }
}

extension StudentDemoSeed {
  public static func makeStudentAddedLogs(plan: StudentPlanView?) -> [StudentAddedSetLog] {
    guard StudentAddedDemoScenario.enabled, let plan, plan.days.count > 1,
      let exercise = plan.days.last?.exercises.last?.exercise
    else { return [] }
    return [
      StudentAddedSetLog(
        id: UUID(), studentID: studentID, planDayID: plan.days[1].id,
        exerciseID: exercise.id, setIndex: 0, loggedAt: Date(),
        loggedDate: TodayWorkoutViewModel.gymDate(Date(), calendar: .current),
        weightKg: 30, reps: 10, rpe: nil, completed: true)
    ]
  }
}
