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
    let startDate = demoCycleStart().addingTimeInterval(
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
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.startOfDay(for: Date())
    // Past training days are fully logged; today is in progress (first two sets);
    // future days are never seeded.
    return plan.days.flatMap { day -> [StudentSetLog] in
      guard day.date <= today, !day.exercises.isEmpty else { return [] }
      let isToday = calendar.isDate(day.date, inSameDayAs: today)
      return day.exercises.flatMap { exercise -> [StudentSetLog] in
        let sets = isToday ? Array(exercise.prescribedSets.prefix(2)) : exercise.prescribedSets
        return sets.map { set in
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

  /// 9 squat e1RM points over ~4 weeks with a gentle upward trend, plus one
  /// unacknowledged PR on the newest point so the launch re-surface path is
  /// exercised in DEMO_MODE (spec 028 §9).
  public static func makeE1RMHistory(studentID: UUID) -> [E1RMHistoryPoint] {
    let squatID = uuid(2_000)
    let baseline = Calendar(identifier: .gregorian).startOfDay(for: Date())
    let e1rms: [Double] = [128.0, 129.5, 128.8, 131.0, 132.4, 131.8, 134.0, 135.2, 137.6]
    return e1rms.enumerated().map { offset, value in
      E1RMHistoryPoint(
        id: uuid(5_000 + offset),
        studentId: studentID,
        exerciseId: squatID,
        setLogId: uuid(5_100 + offset),
        computedAt: baseline.addingTimeInterval(Double(offset - 26) * 86_400 * 3),
        e1RMKg: value,
        sourceWeightKg: 120 + Double(offset) * 2.5,
        sourceReps: 5,
        sourceRPE: 8.0
      )
    }
  }

  public static func makeUnacknowledgedPR(studentID: UUID) -> [PRBreakthroughEvent] {
    let points = makeE1RMHistory(studentID: studentID)
    guard let latest = points.last,
      let previousMax = points.dropLast().map(\.e1RMKg).max()
    else { return [] }
    return [
      PRBreakthroughEvent(
        id: uuid(6_000),
        studentId: studentID,
        exerciseId: latest.exerciseId,
        pointId: latest.id,
        breakthroughE1RMKg: latest.e1RMKg,
        previousMaxE1RMKg: previousMax,
        occurredAt: latest.computedAt,
        acknowledgedAt: nil
      )
    ]
  }

  /// Yesterday filed, today empty — exercises both the "already filed"
  /// toolbar state (yesterday, for coach-side demo in 029) and the auto
  /// prompt (today) in DEMO_MODE (spec 030 §C3).
  public static func makeReadinessHistory(studentID: UUID) -> [ReadinessCheckin] {
    let calendar = Calendar(identifier: .iso8601)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return [
      ReadinessCheckin(
        id: uuid(7_000),
        studentId: studentID,
        checkinDate: formatter.string(from: yesterday),
        sleepQuality: 4,
        mood: 3,
        stress: 2,
        muscleFatigue: [
          MuscleFatigue(muscleGroup: .quad, severity: 3),
          MuscleFatigue(muscleGroup: .core, severity: 1),
        ],
        submittedAt: yesterday
      )
    ]
  }

  private static func uuid(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "02400000-0000-0000-0000-%012d", value))!
  }

  /// The demo cycle is anchored so that "today" is day-offset 3 (深蹲/卧推/休息/**硬拉**…),
  /// i.e. the week began three days ago. This keeps the 锻炼 tab on a real workout
  /// whenever the demo is launched, while leaving genuine *past* training days
  /// (深蹲, 卧推) for 历史/仪表盘 to show — and never seeding future logs.
  private static func demoCycleStart() -> Date {
    let calendar = Calendar(identifier: .gregorian)
    let startOfToday = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .day, value: -3, to: startOfToday) ?? startOfToday
  }
}
