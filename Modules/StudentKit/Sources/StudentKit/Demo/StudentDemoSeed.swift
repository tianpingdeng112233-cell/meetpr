import CoreModels
import Foundation

public enum StudentDemoSeed {
  public static let studentID = UUID(uuidString: "02400000-0000-0000-0000-000000000101")!
  public static let coachID = UUID(uuidString: "02400000-0000-0000-0000-000000000201")!

  public static let coachedStudent = User(
    id: studentID,
    phone: "+15550102400",
    name: "演示学员",
    unitSystem: .metric,
    role: .coachedStudent,
    createdAt: referenceDate,
    updatedAt: referenceDate
  )

  public static let referenceDate = Date(timeIntervalSince1970: 1_768_262_400)  // 2026-01-12

  public static func makePlanView(weekIndex: Int = 1) -> StudentPlanView {
    let startDate = currentWeekStart().addingTimeInterval(
      Double(max(0, weekIndex - 1)) * 7 * 86_400)
    let days = (0..<7).map { offset in
      let date = startDate.addingTimeInterval(Double(offset) * 86_400)
      return StudentPlanDay(
        id: uuid(1_000 + offset),
        date: date,
        exercises: exercises(forDayOffset: offset)
      )
    }
    return StudentPlanView(
      cycleID: uuid(301),
      weekIndex: weekIndex,
      startDate: startDate,
      days: days
    )
  }

  public static func makeHistoricalLogs(
    studentID: UUID = Self.studentID,
    weekIndex: Int = 1
  ) -> [StudentSetLog] {
    let plan = makePlanView(weekIndex: weekIndex)
    return plan.days.prefix(2).flatMap { day in
      day.exercises.flatMap { exercise in
        exercise.prescribedSets.prefix(2).map { set in
          StudentSetLog(
            id: UUID(),
            studentID: studentID,
            planExerciseID: exercise.id,
            setIndex: set.setIndex,
            loggedAt: day.date.addingTimeInterval(Double(3_600 + set.setIndex * 300)),
            weightKg: set.weightKg ?? 60,
            reps: set.reps ?? set.repsMax ?? 5,
            rpe: set.rpe ?? 8,
            completed: true
          )
        }
      }
    }
  }

  public static func makeFeedback(
    coachID: UUID = Self.coachID,
    studentID: UUID = Self.studentID
  ) -> [CoachFeedback] {
    let plan = makePlanView()
    let linkedExerciseID = plan.days.first?.exercises.first?.id
    return [
      CoachFeedback(
        id: uuid(401),
        coachID: coachID,
        studentID: studentID,
        dayDate: plan.days[0].date,
        planExerciseID: linkedExerciseID,
        text: "深蹲第一组速度很好，下一次保持同样节奏，最后一组不要急着起杠。",
        postedAt: referenceDate.addingTimeInterval(4 * 86_400),
        readAt: nil
      ),
      CoachFeedback(
        id: uuid(402),
        coachID: coachID,
        studentID: studentID,
        dayDate: plan.days[1].date,
        text: "卧推动作稳定，肘部路径比上周干净。辅助动作可以控制离心两秒。",
        postedAt: referenceDate.addingTimeInterval(3 * 86_400),
        readAt: nil
      ),
      CoachFeedback(
        id: uuid(403),
        coachID: coachID,
        studentID: studentID,
        text: "本周总体恢复不错，睡眠继续保持。周末拉伸别省。",
        postedAt: referenceDate.addingTimeInterval(86_400),
        readAt: referenceDate.addingTimeInterval(2 * 86_400)
      ),
    ]
  }

  private static func exercises(forDayOffset offset: Int) -> [StudentPlanExercise] {
    switch offset {
    case 0:
      return [
        exercise(.init(index: 0, name: "深蹲", family: .squat, weight: 142.5, reps: 5, rpe: 7.5))
      ]
    case 1:
      return [exercise(.init(index: 1, name: "卧推", family: .bench, weight: 92.5, reps: 5, rpe: 8))]
    case 2:
      return []
    case 3:
      return [
        exercise(.init(index: 2, name: "硬拉", family: .deadlift, weight: 175, reps: 3, rpe: 8.5))
      ]
    case 4:
      return [
        exercise(.init(index: 3, name: "窄握卧推", family: .bench, weight: 75, reps: 6, rpe: nil)),
        exercise(.init(index: 4, name: "坐姿划船", family: nil, weight: 55, reps: 10, rpe: 8)),
      ]
    default:
      return []
    }
  }

  private struct ExerciseSpec {
    let index: Int
    let name: String
    let family: LiftFamily?
    let weight: Decimal
    let reps: Int
    let rpe: Decimal?
  }

  private static func exercise(_ spec: ExerciseSpec) -> StudentPlanExercise {
    let exerciseID = uuid(2_000 + spec.index)
    return StudentPlanExercise(
      id: uuid(3_000 + spec.index),
      exercise: Exercise(
        id: exerciseID,
        name: spec.name,
        exerciseType: spec.family == nil ? .accessory : .mainLift,
        mainLiftFamily: spec.family,
        isCompetitionLift: spec.family != nil && !spec.name.contains("窄握"),
        muscleGroups: spec.family == .bench ? [.chest, .triceps] : [.quad, .glute, .back],
        equipment: spec.family == nil ? [.machine] : [.barbell],
        movementPattern: spec.family == .bench ? [.horizontalPush] : [.squat],
        createdAt: referenceDate
      ),
      sequenceIndex: spec.index,
      prescribedSets: (0..<3).map { setIndex in
        PrescribedSet(
          id: uuid(4_000 + (spec.index * 10) + setIndex),
          setIndex: setIndex,
          weightKg: spec.weight,
          reps: spec.reps,
          repsMax: nil,
          rpe: spec.rpe
        )
      }
    )
  }

  private static func uuid(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "02400000-0000-0000-0000-%012d", value))!
  }

  private static func currentWeekStart() -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let startOfToday = calendar.startOfDay(for: Date())
    let weekday = calendar.component(.weekday, from: startOfToday)
    let distanceFromMonday = (weekday + 5) % 7
    return calendar.date(byAdding: .day, value: -distanceFromMonday, to: startOfToday)
      ?? startOfToday
  }
}
