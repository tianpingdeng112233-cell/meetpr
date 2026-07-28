import CoreModels
import Foundation

// MARK: - Empty-state handoff demo seeds (2026-07-27)

extension StudentDemoSeed {
  public static func makeRestDayPlan(today: Date = Date()) -> StudentPlanView {
    makePlanView(today: today, todayOffset: 2)
  }

  public static func makePlanEndingToday(today: Date = Date()) -> StudentPlanView {
    makePlanView(today: today, todayOffset: 6)
  }

  public static func makeSubmittedTodayLogs(
    plan: StudentPlanView,
    studentID: UUID = Self.studentID,
    today: Date = Date()
  ) -> [StudentSetLog] {
    completedLogs(plan: plan, studentID: studentID) {
      utcCalendar.isDate($0.date, inSameDayAs: today)
    }
  }

  public static func makeAllCompletedLogs(
    plan: StudentPlanView,
    studentID: UUID = Self.studentID,
    today: Date = Date()
  ) -> [StudentSetLog] {
    let endOfToday = utcCalendar.startOfDay(for: today).addingTimeInterval(86_400)
    return completedLogs(plan: plan, studentID: studentID) { $0.date < endOfToday }
  }

  public static func makeSingleSessionLogs(
    plan: StudentPlanView,
    studentID: UUID = Self.studentID
  ) -> [StudentSetLog] {
    guard
      let firstTrainingDay =
        plan.days.first(where: { day in
          day.exercises.contains { $0.exercise.mainLiftFamily == .squat }
        })
        ?? plan.days.first(where: { !$0.exercises.isEmpty })
    else {
      return []
    }
    return Array(
      completedLogs(plan: plan, studentID: studentID) {
        $0.id == firstTrainingDay.id
      }
      .prefix(1)
    )
  }

  public static func makeFormingE1RMHistory(
    studentID: UUID = Self.studentID
  ) -> [E1RMHistoryPoint] {
    guard
      let squatExerciseID =
        makePlanView().days
        .flatMap(\.exercises)
        .first(where: { $0.exercise.mainLiftFamily == .squat })?
        .exercise.id
    else {
      return []
    }
    return Array(
      makeE1RMHistory(studentID: studentID)
        .filter { $0.exerciseId == squatExerciseID }
        .prefix(1)
    )
  }

  private static func completedLogs(
    plan: StudentPlanView,
    studentID: UUID,
    includesDay: (StudentPlanDay) -> Bool
  ) -> [StudentSetLog] {
    plan.days
      .filter(includesDay)
      .flatMap { day in
        day.exercises.flatMap { exercise in
          exercise.prescribedSets.map { set in
            StudentSetLog(
              id: UUID(),
              studentID: studentID,
              planExerciseID: exercise.id,
              exerciseID: exercise.exercise.id,
              setIndex: set.setIndex,
              loggedAt: day.date.addingTimeInterval(
                Double(21 * 3_600 + set.setIndex * 300)
              ),
              weightKg: set.weightKg ?? 0,
              reps: set.reps ?? set.repsMax ?? 0,
              rpe: set.rpe,
              completed: true
            )
          }
        }
      }
  }
}
