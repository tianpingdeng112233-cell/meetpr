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

  public static let referenceDate = Date(timeIntervalSince1970: 1_768_262_400)  // 2026-01-13

  public static func makePlanView(weekIndex: Int = 1, today: Date = Date()) -> StudentPlanView {
    let startDate = demoCycleStart(today: today).addingTimeInterval(
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
      endDate: startDate.addingTimeInterval(6 * 86_400),
      days: days
    )
  }

  public static func makeHistoricalLogs(
    studentID: UUID = Self.studentID,
    weekIndex: Int = 1,
    includeToday: Bool = true
  ) -> [StudentSetLog] {
    let plan = makePlanView(weekIndex: weekIndex)
    let calendar = utcCalendar
    let today = calendar.startOfDay(for: Date())
    // Past training days are fully logged; today is in progress (first two sets);
    // future days are never seeded.
    return plan.days.flatMap { day -> [StudentSetLog] in
      guard day.date <= today, !day.exercises.isEmpty else { return [] }
      let isToday = calendar.isDate(day.date, inSameDayAs: today)
      guard includeToday || !isToday else { return [] }
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
        exercise(
          .init(
            index: 2, name: "硬拉", family: .deadlift, weight: 175, reps: 3, rpe: 8.5,
            note: "D170/L190 递增5kg,顶组留一,腰部有感觉就停"))
      ]
    case 4:
      // 深蹲主项 + 窄握卧推变式(+ 坐姿划船辅助)→ 角标 "SB"(演示组合日 + S 在 B 前排序 +
      // 辅助动作不计入)。
      return [
        exercise(.init(index: 6, name: "深蹲", family: .squat, weight: 130, reps: 5, rpe: 7)),
        exercise(
          .init(
            index: 3, name: "窄握卧推", family: .bench, weight: 75, reps: 6, rpe: nil,
            type: .mainLiftVariation)),
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
    /// Explicit role; defaults to .accessory when `family` is nil, else .mainLift.
    /// Set `.mainLiftVariation` for 变式 (暂停深蹲 / 窄握卧推 等).
    var type: ExerciseType?
    /// Exercise-level coach note (web 备注 column passthrough).
    var note: String?
  }

  private static func exercise(_ spec: ExerciseSpec) -> StudentPlanExercise {
    let exerciseID = uuid(2_000 + spec.index)
    let exerciseType = spec.type ?? (spec.family == nil ? .accessory : .mainLift)
    return StudentPlanExercise(
      id: uuid(3_000 + spec.index),
      exercise: Exercise(
        id: exerciseID,
        name: spec.name,
        exerciseType: exerciseType,
        mainLiftFamily: spec.family,
        isCompetitionLift: exerciseType == .mainLift,
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
          rpe: spec.rpe,
          coachNote: setIndex == 0 ? "下放控制 3 秒" : nil
        )
      },
      notes: spec.note
    )
  }

  /// Three main-lift e1RM lines over ~4 weeks, plus one unacknowledged PR on
  /// the newest point so the launch re-surface path is exercised in DEMO_MODE.
  public static func makeE1RMHistory(studentID: UUID) -> [E1RMHistoryPoint] {
    let baseline = Calendar(identifier: .gregorian).startOfDay(for: Date())
    return makeE1RMHistory(
      studentID: studentID,
      exerciseID: uuid(2_000),
      idOffset: 5_000,
      baseline: baseline,
      values: [128.0, 129.5, 128.8, 131.0, 132.4, 131.8, 134.0, 135.2, 137.6]
    )
      + makeE1RMHistory(
        studentID: studentID,
        exerciseID: uuid(2_001),
        idOffset: 5_100,
        baseline: baseline,
        values: [86.0, 87.2, 88.0, 88.5, 89.4, 90.1, 91.0]
      )
      + makeE1RMHistory(
        studentID: studentID,
        exerciseID: uuid(2_002),
        idOffset: 5_200,
        baseline: baseline,
        values: [168.0, 170.0, 171.5, 173.0, 174.2, 176.0, 178.5]
      )
  }

  public static func makeUnacknowledgedPR(studentID: UUID) -> [PRBreakthroughEvent] {
    let points = makeE1RMHistory(studentID: studentID)
    guard let latest = points.max(by: { $0.computedAt < $1.computedAt }),
      let previousMax =
        points
        .filter({ $0.exerciseId == latest.exerciseId && $0.id != latest.id })
        .map(\.e1RMKg)
        .max()
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
  private static func demoCycleStart(today: Date) -> Date {
    let calendar = utcCalendar
    let startOfToday = calendar.startOfDay(for: today)
    return calendar.date(byAdding: .day, value: -3, to: startOfToday) ?? startOfToday
  }

  /// Backend plan-day dates decode as UTC-midnight anchors; the demo seed must
  /// match that shape or UTC-gated features (e.g. 今天有事 shift entry) behave
  /// differently in DEMO_MODE than against the real backend.
  static var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
  }
}

// MARK: - e1RM demo helpers (extension keeps the enum body within the
// type-body-length budget)

extension StudentDemoSeed {
  private static func makeE1RMHistory(
    studentID: UUID,
    exerciseID: UUID,
    idOffset: Int,
    baseline: Date,
    values: [Double]
  ) -> [E1RMHistoryPoint] {
    values.enumerated().map { offset, value in
      E1RMHistoryPoint(
        id: uuid(idOffset + offset),
        studentId: studentID,
        exerciseId: exerciseID,
        setLogId: uuid(idOffset + 50 + offset),
        computedAt: baseline.addingTimeInterval(Double(offset - 26) * 86_400 * 3),
        e1RMKg: value,
        sourceWeightKg: value * 0.88,
        sourceReps: 5,
        sourceRPE: 8.0
      )
    }
  }
}

// MARK: - Spec 031/032 demo seeds (extension keeps the enum body within
// the type-body-length budget)

extension StudentDemoSeed {
  /// Fully completed 29-field profile so the nine archive cards demo with
  /// real-looking data (spec 032 D10 / spec 031 D10: the demo student is
  /// past onboarding — the wizard itself demos on a fresh staging account).
  public static func makeOnboardingProfile(studentID: UUID) -> OnboardingProfile {
    OnboardingProfile(
      userId: studentID,
      unitPreference: .kg,
      gender: .male,
      birthDate: "2001-03-15",
      heightCm: 178,
      weightKg: 83,
      trainingYears: 3,
      squatStance: .lowBar,
      deadliftStyle: .conventional,
      benchGrip: .standard,
      squat1RMKg: 180,
      bench1RMKg: 120,
      deadlift1RMKg: 220,
      trainingDays: [.mon, .wed, .fri, .sat],
      gymTier: .commercial,
      equipmentOverrides: EquipmentCatalog.prefill(for: .commercial),
      dailyLifeIntensity: 3,
      lifeStress: 4,
      recoverySpeed: 3,
      sleepHours: 3,
      muscleGroupsToStrengthen: [.quad, .hamstring, .shoulder],
      uploadAttachmentIds: [],
      injuryNotes: "左肩撞击综合征",
      injuryAreas: [.shoulder],
      isCompeting: true,
      competitionDate: "2026-07-25",
      targetWeightClass: "IPF 83kg",
      noteToCoach: "想冲全国赛,请多关注深蹲底部速度",
      completedAt: referenceDate,
      createdAt: referenceDate,
      updatedAt: referenceDate
    )
  }

  /// Accepted bond — the demo student goes straight through the BindGate
  /// into the 5 tabs (spec 031 D10: zero regression for the existing demo).
  public static func makeAcceptedBindRequest(
    studentID: UUID,
    coachID: UUID = StudentDemoSeed.coachID
  ) -> BindRequest {
    BindRequest(
      id: uuid(8_000),
      studentId: studentID,
      coachId: coachID,
      coachDisplayName: "演示教练",
      inviteCodeId: uuid(8_001),
      status: .accepted,
      submittedAt: referenceDate,
      respondedAt: referenceDate.addingTimeInterval(3_600),
      expiredAt: referenceDate.addingTimeInterval(7 * 86_400)
    )
  }
}
