// Demo fixture catalog intentionally stays co-located for cross-feature consistency.
// swiftlint:disable file_length
import CoreModels
import Foundation

// swiftlint:disable:next type_body_length
public enum StudentDemoSeed {
  private static let canonicalChineseLocale = Locale(identifier: "zh-Hans")
  private static let englishLocale = Locale(identifier: "en")
  public static let studentID = UUID(uuidString: "02400000-0000-0000-0000-000000000101")!
  public static let coachID = UUID(uuidString: "02400000-0000-0000-0000-000000000201")!

  public static let coachedStudent = User(
    id: studentID,
    phone: "+15550102400",
    name: StudentStrings.localized(.studentDemoSeed001),
    unitSystem: .metric,
    role: .coachedStudent,
    createdAt: referenceDate,
    updatedAt: referenceDate
  )

  public static let referenceDate = Date(timeIntervalSince1970: 1_768_262_400)  // 2026-01-13

  public static func makePlanView(
    weekIndex: Int = 1,
    today: Date = Date(),
    todayOffset: Int = 3,
    selectedCalendar: Calendar = .current
  ) -> StudentPlanView {
    let startDate = demoCycleStart(
      today: today,
      todayOffset: todayOffset,
      selectedCalendar: selectedCalendar
    )
    .addingTimeInterval(Double(max(0, weekIndex - 1)) * 7 * 86_400)
    let days = (0..<8).map { offset in
      let date = startDate.addingTimeInterval(Double(offset) * 86_400)
      return StudentPlanDay(
        id: uuid(1_000 + offset),
        weekNumber: (offset / 4) + 1,
        dayOfWeek: (offset % 4) + 1,
        sortOrder: offset,
        date: date,
        completedAt: offset < 2 ? date.addingTimeInterval(20 * 3_600) : nil,
        completionSource: offset < 2 ? "auto" : nil,
        exercises: exercises(forDayOffset: offset)
      )
    }
    return StudentPlanView(
      cycleID: uuid(301),
      weekIndex: weekIndex,
      startDate: startDate,
      endDate: startDate.addingTimeInterval(7 * 86_400),
      publishedAt: referenceDate,
      days: days
    )
  }

  public static func makeHistoricalLogs(
    studentID: UUID = Self.studentID,
    weekIndex: Int = 1,
    includeToday: Bool = true
  ) -> [StudentSetLog] {
    let plan = makePlanView(weekIndex: weekIndex)
    // W1D1–D2 are complete; W1D3 is deliberately partial so reopening the
    // demo proves that partial logs do not advance the sequence cursor.
    return plan.days.prefix(includeToday ? 3 : 2).flatMap { day -> [StudentSetLog] in
      let isCursor = day.dayOfWeek == 3
      return day.exercises.flatMap { exercise -> [StudentSetLog] in
        let sets = isCursor ? Array(exercise.prescribedSets.prefix(2)) : exercise.prescribedSets
        return sets.map { set in
          StudentSetLog(
            id: UUID(),
            studentID: studentID,
            planExerciseID: exercise.id,
            setIndex: set.setIndex,
            loggedAt: day.scheduledDate.addingTimeInterval(Double(3_600 + set.setIndex * 300)),
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
    let newestFeedbackAt = Date().addingTimeInterval(-120)
    return [
      CoachFeedback(
        id: uuid(401),
        coachID: coachID,
        studentID: studentID,
        dayDate: plan.days[0].scheduledDate,
        planExerciseID: linkedExerciseID,
        videoID: uuid(411),
        video: demoFeedbackVideo(
          id: uuid(411), loggedAt: newestFeedbackAt.addingTimeInterval(-86_400)),
        text: StudentStrings.localized(.studentDemoSeed002),
        postedAt: newestFeedbackAt,
        readAt: nil
      ),
      CoachFeedback(
        id: uuid(402),
        coachID: coachID,
        studentID: studentID,
        dayDate: plan.days[1].scheduledDate,
        text: StudentStrings.localized(.studentDemoSeed003),
        postedAt: newestFeedbackAt.addingTimeInterval(-180),
        readAt: nil
      ),
      CoachFeedback(
        id: uuid(403),
        coachID: coachID,
        studentID: studentID,
        text: StudentStrings.localized(.studentDemoSeed004),
        postedAt: newestFeedbackAt.addingTimeInterval(-420),
        readAt: newestFeedbackAt.addingTimeInterval(-360)
      ),
    ]
  }

  // swiftlint:disable:next function_body_length
  private static func exercises(forDayOffset offset: Int) -> [StudentPlanExercise] {
    let templates: [StudentPlanExercise]
    switch offset {
    case 0:
      templates = [
        exercise(
          .init(
            index: 0,
            name: StudentStrings.localized(
              .studentDemoSeed005,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed005, locale: englishLocale),
            family: .squat, weight: 142.5, reps: 5, rpe: 7.5,
            note: StudentStrings.localized(.studentDemoSeed006)))
      ]
    case 1:
      templates = [
        exercise(
          .init(
            index: 1,
            name: StudentStrings.localized(
              .studentDemoSeed007,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed007, locale: englishLocale),
            family: .bench, weight: 92.5, reps: 5, rpe: 8
          )
        )
      ]
    case 2, 6:
      templates = [
        exercise(
          .init(
            index: 2,
            name: StudentStrings.localized(
              .studentDemoSeed008,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed008, locale: englishLocale),
            family: .deadlift, weight: 175, reps: 3, rpe: 8.5,
            note: StudentStrings.localized(.studentDemoSeed009)))
      ]
    case 3, 7:
      // 深蹲主项 + 窄握卧推变式(+ 坐姿划船辅助)→ 角标 "SB"(演示组合日 + S 在 B 前排序 +
      // 辅助动作不计入)。
      templates = [
        exercise(
          .init(
            index: 6,
            name: StudentStrings.localized(
              .studentDemoSeed005,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed005, locale: englishLocale),
            family: .squat, weight: 130, reps: 5, rpe: 7
          )
        ),
        exercise(
          .init(
            index: 3,
            name: StudentStrings.localized(
              .studentDemoSeed010,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed010, locale: englishLocale),
            family: .bench, weight: 75, reps: 6, rpe: nil,
            type: .mainLiftVariation)),
        exercise(
          .init(
            index: 4,
            name: StudentStrings.localized(
              .studentDemoSeed011,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed011, locale: englishLocale),
            family: nil, weight: 55, reps: 10, rpe: 8
          )
        ),
      ]
    case 4:
      templates = [
        exercise(
          .init(
            index: 0,
            name: StudentStrings.localized(
              .studentDemoSeed005,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed005, locale: englishLocale),
            family: .squat, weight: 145, reps: 4, rpe: 8
          )
        )
      ]
    case 5:
      templates = [
        exercise(
          .init(
            index: 1,
            name: StudentStrings.localized(
              .studentDemoSeed007,
              locale: canonicalChineseLocale
            ),
            nameEn: StudentStrings.localized(.studentDemoSeed007, locale: englishLocale),
            family: .bench, weight: 95, reps: 4, rpe: 8
          )
        )
      ]
    default:
      templates = []
    }
    return uniquelyIdentified(templates, dayOffset: offset)
  }

  private static func uniquelyIdentified(
    _ templates: [StudentPlanExercise],
    dayOffset: Int
  ) -> [StudentPlanExercise] {
    templates.map { template in
      StudentPlanExercise(
        id: uuid(30_000 + (dayOffset * 100) + template.sequenceIndex),
        exercise: template.exercise,
        sequenceIndex: template.sequenceIndex,
        prescribedSets: template.prescribedSets.map { set in
          PrescribedSet(
            id: uuid(
              40_000 + (dayOffset * 100) + (template.sequenceIndex * 10) + set.setIndex),
            setIndex: set.setIndex,
            weightKg: set.weightKg,
            reps: set.reps,
            repsMax: set.repsMax,
            rpe: set.rpe,
            restSeconds: set.restSeconds,
            coachNote: set.coachNote
          )
        },
        notes: template.notes
      )
    }
  }

  private static func exercise(_ spec: ExerciseSpec) -> StudentPlanExercise {
    let exerciseID = uuid(2_000 + spec.index)
    let exerciseType = spec.type ?? (spec.family == nil ? .accessory : .mainLift)
    return StudentPlanExercise(
      id: uuid(3_000 + spec.index),
      exercise: Exercise(
        id: exerciseID,
        name: spec.name,
        nameEn: spec.nameEn,
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
          coachNote: setIndex == 0 ? StudentStrings.localized(.studentDemoSeed012) : nil
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
      family: .squat,
      baseline: baseline,
      values: [128.0, 129.5, 128.8, 131.0, 132.4, 131.8, 134.0, 135.2, 137.6]
    )
      + makeE1RMHistory(
        studentID: studentID,
        exerciseID: uuid(2_001),
        family: .bench,
        baseline: baseline,
        values: [86.0, 87.2, 88.0, 88.5, 89.4, 90.1, 91.0]
      )
      + makeE1RMHistory(
        studentID: studentID,
        exerciseID: uuid(2_002),
        family: .deadlift,
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
        family: latest.family,
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
  private static func demoCycleStart(
    today: Date,
    todayOffset: Int,
    selectedCalendar: Calendar
  ) -> Date {
    let calendar = utcCalendar
    let startOfToday =
      PlanCalendarDayIdentity.planDate(
        matching: today,
        selectedCalendar: selectedCalendar
      ) ?? calendar.startOfDay(for: today)
    return calendar.date(
      byAdding: .day,
      value: -min(max(todayOffset, 0), 6),
      to: startOfToday
    ) ?? startOfToday
  }

  /// Backend plan-day dates decode as UTC-midnight anchors; the demo seed must
  /// match that shape or date-keyed history and notification routes behave
  /// differently in DEMO_MODE than against the real backend.
  static var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
  }
}

/// Demo exercise recipe consumed by `StudentDemoSeed.exercise(_:)`; lives at
/// file scope to keep the enum body within the type-body-length budget.
private struct ExerciseSpec {
  let index: Int
  let name: String
  var nameEn: String?
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

// MARK: - e1RM demo helpers (extension keeps the enum body within the
// type-body-length budget)

extension StudentDemoSeed {
  private static func makeE1RMHistory(
    studentID: UUID,
    exerciseID: UUID,
    family: LiftFamily,
    baseline: Date,
    values: [Double]
  ) -> [E1RMHistoryPoint] {
    let idOffset =
      switch family {
      case .squat: 5_000
      case .bench: 5_100
      case .deadlift: 5_200
      }
    return values.enumerated().map { offset, value in
      E1RMHistoryPoint(
        id: uuid(idOffset + offset),
        studentId: studentID,
        exerciseId: exerciseID,
        family: family,
        setLogId: uuid(idOffset + 50 + offset),
        computedAt: baseline.addingTimeInterval(Double(offset - 26) * 86_400 * 3),
        e1RMKg: value,
        sourceWeightKg: demoSourceWeights[exerciseID]?[offset] ?? value,
        sourceReps: 5,
        sourceRPE: 8.0
      )
    }
  }

  private static let demoSourceWeights = [
    uuid(2_000): [130, 130, 132.5, 132.5, 135, 137.5, 137.5, 140, 142.5],
    uuid(2_001): [80, 82.5, 82.5, 85, 87.5, 90, 92.5],
    uuid(2_002): [155, 157.5, 160, 165, 167.5, 170, 175],
  ]
}

// MARK: - Spec 031/032 demo seeds (extension keeps the enum body within
// the type-body-length budget)

extension StudentDemoSeed {
  /// Fully completed 29-field profile so the nine archive cards demo with
  /// real-looking data (spec 032 D10 / spec 031 D10: the demo student is
  /// past onboarding — the wizard itself demos on a fresh staging account).
  public static func makeOnboardingProfile(
    studentID: UUID,
    isCompeting: Bool = true
  ) -> OnboardingProfile {
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
      injuryNotes: StudentStrings.localized(.studentDemoSeed013),
      injuryAreas: [.shoulder],
      isCompeting: isCompeting,
      competitionDate: isCompeting ? demoCompetitionDate() : nil,
      targetWeightClass: "IPF 83kg",
      noteToCoach: StudentStrings.localized(.studentDemoSeed014),
      completedAt: referenceDate,
      createdAt: referenceDate,
      updatedAt: referenceDate
    )
  }

  private static func demoCompetitionDate() -> String {
    let calendar = Calendar.current
    let date = calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    return DateOnly.string(from: date)
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
      coachDisplayName: StudentStrings.localized(.studentDemoSeed015),
      inviteCodeId: uuid(8_001),
      status: .accepted,
      submittedAt: referenceDate,
      respondedAt: referenceDate.addingTimeInterval(3_600),
      expiredAt: referenceDate.addingTimeInterval(7 * 86_400)
    )
  }
}

// swiftlint:enable file_length
