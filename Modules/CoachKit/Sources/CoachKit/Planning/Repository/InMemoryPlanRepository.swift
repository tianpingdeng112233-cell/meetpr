import CoreModels
import Foundation

// swiftlint:disable type_body_length
public actor InMemoryPlanRepository: PlanRepository {
  private var students: [CoachStudentSummary]
  private var catalog: [Exercise]
  private var publishedPlans: [TrainingPlan] = []

  public init(students: [CoachStudentSummary], catalog: [Exercise]) {
    self.students = students
    self.catalog = catalog
  }

  public static func preview() -> InMemoryPlanRepository {
    InMemoryPlanRepository(
      students: previewStudents(),
      catalog: previewCatalog()
    )
  }

  public func fetchStudents() async throws -> [CoachStudentSummary] {
    students
  }

  public func fetchMainLiftCatalog() async throws -> [Exercise] {
    catalog.filter {
      $0.exerciseType == .mainLift || $0.exerciseType == .mainLiftVariation
    }
  }

  public func fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise] {
    catalog
      .filter { exercise in
        guard exercise.exerciseType == .accessory else { return false }
        let missesMuscleGroup =
          !filters.muscleGroups.isEmpty
          && Set(exercise.muscleGroups).isDisjoint(with: filters.muscleGroups)
        if missesMuscleGroup {
          return false
        }
        let missesEquipment =
          !filters.equipment.isEmpty
          && Set(exercise.equipment).isDisjoint(with: filters.equipment)
        if missesEquipment {
          return false
        }
        let missesMovementPattern =
          !filters.movementPatterns.isEmpty
          && Set(exercise.movementPattern).isDisjoint(with: filters.movementPatterns)
        if missesMovementPattern {
          return false
        }
        return true
      }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  public func publishPlan(
    plan: TrainingPlan,
    days: [PlanDay],
    exercises: [PlanExercise]
  ) async throws {
    _ = days
    _ = exercises
    publishedPlans.append(plan)
  }

  public func publishedPlansSnapshot() -> [TrainingPlan] {
    publishedPlans
  }

  // swiftlint:disable:next function_body_length
  private static func previewStudents() -> [CoachStudentSummary] {
    let now = Date()
    let activeProfile = StudentProfile(
      id: uuid(1),
      userID: uuid(2),
      trainingMode: .coached,
      trainingYears: 3,
      squatStance: .lowBar,
      deadliftStance: .conventional,
      benchGrip: .standard,
      currentSquat1RM: Decimal(180),
      bench1RM: Decimal(120),
      deadlift1RM: Decimal(220),
      trainingDaysOfWeek: [1, 3, 5, 6],
      gymTier: .commercial,
      dailyIntensityLevel: 3,
      lifeStressLevel: 3,
      recoverySpeed: 4,
      sleepHours: 7,
      musclesToStrengthen: ["股四", "腘绳", "肩"],
      competitionTargeting: true,
      competitionDate: now.addingTimeInterval(8_812_800),
      notesToCoach: "左肩撞击综合征，卧推需要保守递进。",
      createdAt: now,
      updatedAt: now
    )

    let evaluationProfile = StudentProfile(
      id: uuid(3),
      userID: uuid(4),
      trainingMode: .coached,
      trainingYears: 1,
      squatStance: .highBar,
      deadliftStance: .sumo,
      benchGrip: .standard,
      currentSquat1RM: Decimal(120),
      bench1RM: Decimal(75),
      deadlift1RM: Decimal(150),
      trainingDaysOfWeek: [2, 4, 6],
      gymTier: .commercial,
      dailyIntensityLevel: 2,
      lifeStressLevel: 2,
      recoverySpeed: 3,
      sleepHours: 7,
      competitionTargeting: false,
      createdAt: now,
      updatedAt: now
    )

    let abnormalProfile = StudentProfile(
      id: uuid(5),
      userID: uuid(6),
      trainingMode: .coached,
      trainingYears: 2,
      squatStance: .lowBar,
      deadliftStance: .conventional,
      benchGrip: .wide,
      currentSquat1RM: Decimal(150),
      bench1RM: Decimal(95),
      deadlift1RM: Decimal(180),
      trainingDaysOfWeek: [1, 3, 5],
      gymTier: .homeWithRack,
      dailyIntensityLevel: 4,
      lifeStressLevel: 4,
      recoverySpeed: 2,
      sleepHours: 6,
      competitionTargeting: false,
      createdAt: now,
      updatedAt: now
    )

    let secondActiveProfile = StudentProfile(
      id: uuid(7),
      userID: uuid(8),
      trainingMode: .coached,
      trainingYears: 4,
      squatStance: .highBar,
      deadliftStance: .sumo,
      benchGrip: .narrow,
      currentSquat1RM: Decimal(140),
      bench1RM: Decimal(90),
      deadlift1RM: Decimal(170),
      trainingDaysOfWeek: [1, 2, 4, 6],
      gymTier: .professional,
      dailyIntensityLevel: 3,
      lifeStressLevel: 2,
      recoverySpeed: 4,
      sleepHours: 8,
      competitionTargeting: false,
      createdAt: now,
      updatedAt: now
    )

    return [
      CoachStudentSummary(
        id: evaluationProfile.userID,
        profile: evaluationProfile,
        displayName: "王小明",
        status: .inEvaluation(remainingDays: 4, remainingHours: 13)
      ),
      CoachStudentSummary(
        id: activeProfile.userID,
        profile: activeProfile,
        displayName: "张三",
        status: .active
      ),
      CoachStudentSummary(
        id: secondActiveProfile.userID,
        profile: secondActiveProfile,
        displayName: "李四",
        status: .active
      ),
      CoachStudentSummary(
        id: abnormalProfile.userID,
        profile: abnormalProfile,
        displayName: "钱六",
        status: .abnormal(reason: .noTrainingForDays(3))
      ),
    ]
  }

  // swiftlint:disable:next function_body_length
  private static func previewCatalog() -> [Exercise] {
    let now = Date()
    return [
      Exercise(
        id: uuid(20),
        name: "竞技深蹲",
        exerciseType: .mainLift,
        mainLiftFamily: .squat,
        isCompetitionLift: true,
        muscleGroups: [.quad, .glute],
        equipment: [.barbell],
        movementPattern: [.push],
        createdAt: now
      ),
      Exercise(
        id: uuid(21),
        name: "竞技卧推",
        exerciseType: .mainLift,
        mainLiftFamily: .bench,
        isCompetitionLift: true,
        muscleGroups: [.chest, .triceps],
        equipment: [.barbell],
        movementPattern: [.push],
        createdAt: now
      ),
      Exercise(
        id: uuid(22),
        name: "竞技硬拉",
        exerciseType: .mainLift,
        mainLiftFamily: .deadlift,
        isCompetitionLift: true,
        muscleGroups: [.back, .hamstring],
        equipment: [.barbell],
        movementPattern: [.pull],
        createdAt: now
      ),
      Exercise(
        id: uuid(23),
        name: "暂停卧推",
        exerciseType: .mainLiftVariation,
        mainLiftFamily: .bench,
        isCompetitionLift: false,
        muscleGroups: [.chest, .triceps],
        equipment: [.barbell],
        movementPattern: [.push],
        createdAt: now
      ),
      Exercise(
        id: uuid(24),
        name: "节奏硬拉",
        exerciseType: .mainLiftVariation,
        mainLiftFamily: .deadlift,
        isCompetitionLift: false,
        muscleGroups: [.back, .hamstring],
        equipment: [.barbell],
        movementPattern: [.pull],
        createdAt: now
      ),
      Exercise(
        id: uuid(25),
        name: "前蹲举",
        exerciseType: .mainLiftVariation,
        mainLiftFamily: .squat,
        isCompetitionLift: false,
        muscleGroups: [.quad, .core],
        equipment: [.barbell],
        movementPattern: [.push],
        createdAt: now
      ),
    ] + previewAccessoryCatalog(createdAt: now)
  }

  private static func previewAccessoryCatalog(createdAt: Date) -> [Exercise] {
    [
      accessory(200, "哈克深蹲", [.quad], [.machine], [.push], createdAt),
      accessory(201, "杠铃前蹲举", [.quad, .core], [.barbell], [.push], createdAt),
      accessory(202, "杠铃箭步蹲", [.quad, .glute], [.barbell], [.push], createdAt),
      accessory(203, "倒蹬", [.quad], [.machine], [.push], createdAt),
      accessory(204, "腿屈伸", [.quad], [.machine], [.push], createdAt),
      accessory(205, "高脚杯深蹲", [.quad], [.dumbbell], [.push], createdAt),
      accessory(206, "臀冲", [.glute], [.barbell], [.push], createdAt),
      accessory(207, "罗马尼亚硬拉", [.glute, .hamstring], [.barbell], [.pull], createdAt),
      accessory(208, "单腿臀冲", [.glute], [.bodyweight], [.push], createdAt),
      accessory(209, "反向髋伸", [.glute, .hamstring], [.machine], [.pull], createdAt),
      accessory(210, "北欧腘绳", [.hamstring], [.bodyweight], [.pull], createdAt),
      accessory(211, "腿弯举", [.hamstring], [.machine], [.pull], createdAt),
      accessory(212, "哑铃罗马尼亚硬拉", [.hamstring, .glute], [.dumbbell], [.pull], createdAt),
      accessory(213, "上斜哑铃推", [.chest], [.dumbbell], [.push], createdAt),
      accessory(214, "平板哑铃推", [.chest], [.dumbbell], [.push], createdAt),
      accessory(215, "双杠臂屈伸", [.chest, .triceps], [.bodyweight], [.push], createdAt),
      accessory(216, "龙门夹胸", [.chest], [.machine], [.push], createdAt),
      accessory(217, "俯卧撑", [.chest], [.bodyweight], [.push], createdAt),
      accessory(218, "引体向上", [.back, .biceps], [.bodyweight], [.pull], createdAt),
      accessory(219, "杠铃划船", [.back], [.barbell], [.pull], createdAt),
      accessory(220, "高位下拉", [.back], [.machine], [.pull], createdAt),
      accessory(221, "单臂哑铃划船", [.back], [.dumbbell], [.pull], createdAt),
      accessory(222, "哑铃肩推", [.shoulder], [.dumbbell], [.push], createdAt),
      accessory(223, "侧平举", [.shoulder], [.dumbbell], [.push], createdAt),
      accessory(224, "面拉", [.shoulder, .back], [.machine], [.pull], createdAt),
      accessory(225, "杠铃弯举", [.biceps], [.barbell], [.pull], createdAt),
      accessory(226, "哑铃弯举", [.biceps], [.dumbbell], [.pull], createdAt),
      accessory(227, "三头绳索下压", [.triceps], [.machine], [.push], createdAt),
      accessory(228, "仰卧臂屈伸", [.triceps], [.barbell], [.push], createdAt),
      accessory(229, "窄距俯卧撑", [.triceps], [.bodyweight], [.push], createdAt),
      accessory(230, "平板支撑", [.core], [.bodyweight], [.push], createdAt),
      accessory(231, "卷腹", [.core], [.bodyweight], [.pull], createdAt),
      accessory(232, "哑铃转体", [.core], [.dumbbell], [.pull], createdAt),
      accessory(233, "农夫行走", [.core, .back], [.dumbbell], [.pull], createdAt),
    ]
  }

  // swiftlint:disable:next function_parameter_count
  private static func accessory(
    _ byte: UInt8,
    _ name: String,
    _ muscleGroups: [MuscleGroup],
    _ equipment: [Equipment],
    _ movementPattern: [MovementPattern],
    _ createdAt: Date
  ) -> Exercise {
    Exercise(
      id: uuid(byte),
      name: name,
      exerciseType: .accessory,
      mainLiftFamily: nil,
      isCompetitionLift: false,
      muscleGroups: muscleGroups,
      equipment: equipment,
      movementPattern: movementPattern,
      createdByCoachID: nil,
      createdAt: createdAt
    )
  }

  private static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }
}
// swiftlint:enable type_body_length
