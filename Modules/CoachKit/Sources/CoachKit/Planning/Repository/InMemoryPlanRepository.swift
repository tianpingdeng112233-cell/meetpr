import CoreModels
import Foundation
import RepositoryContracts

// swiftlint:disable type_body_length
public actor InMemoryPlanRepository: PlanRepository {
  private var students: [CoachStudentSummary]
  private var catalog: [Exercise]
  private var publishedPlans: [TrainingPlan] = []
  private let store: (any StudentPlanStore)?

  public init(
    students: [CoachStudentSummary],
    catalog: [Exercise],
    store: (any StudentPlanStore)? = nil
  ) {
    self.students = students
    self.catalog = catalog
    self.store = store
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
    exercises: [PlanExercise],
    sets: [PlanSet]
  ) async throws {
    publishedPlans.append(plan)
    guard let store else { return }
    // V0.1 publishes cycle week 1 as the student's current plan; per-date
    // current-week selection is deferred to backend wiring (spec 026).
    let projection = PlanToStudentProjection.project(
      plan: plan,
      days: days,
      exercises: exercises,
      sets: sets,
      catalog: catalog,
      weekIndex: 1
    )
    await store.savePublishedProjection(projection, forStudent: plan.traineeID)
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

    let noOneRMProfile = StudentProfile(
      id: uuid(9),
      userID: uuid(10),
      trainingMode: .coached,
      trainingYears: 0,
      squatStance: .highBar,
      deadliftStance: .conventional,
      benchGrip: .standard,
      currentSquat1RM: Decimal(0),
      bench1RM: Decimal(0),
      deadlift1RM: Decimal(0),
      trainingDaysOfWeek: [2, 5],
      gymTier: .commercial,
      dailyIntensityLevel: 2,
      lifeStressLevel: 3,
      recoverySpeed: 3,
      sleepHours: 7,
      competitionTargeting: false,
      notesToCoach: "刚开始评估，暂不使用百分比强度。",
      createdAt: now,
      updatedAt: now
    )

    return [
      CoachStudentSummary(
        id: evaluationProfile.userID,
        profile: evaluationProfile,
        displayName: "王晨曦",
        status: .inEvaluation(remainingDays: 4, remainingHours: 13)
      ),
      CoachStudentSummary(
        id: activeProfile.userID,
        profile: activeProfile,
        displayName: "张以恒",
        status: .active
      ),
      CoachStudentSummary(
        id: secondActiveProfile.userID,
        profile: secondActiveProfile,
        displayName: "李嘉宁",
        status: .active
      ),
      CoachStudentSummary(
        id: noOneRMProfile.userID,
        profile: noOneRMProfile,
        displayName: "赵安然",
        status: .inEvaluation(remainingDays: 6, remainingHours: 2)
      ),
      CoachStudentSummary(
        id: abnormalProfile.userID,
        profile: abnormalProfile,
        displayName: "钱骁",
        status: .abnormal(reason: .noTrainingForDays(3))
      ),
    ]
  }

  private static func previewCatalog() -> [Exercise] {
    syntheticCompetitionLifts() + loadBundledCatalogV2()
  }

  static func loadBundledCatalogV2() -> [Exercise] {
    guard
      let url = Bundle.module.url(
        forResource: "exercise-catalog-v2",
        withExtension: "json"
      )
    else {
      assertionFailure("Bundled catalog v2 missing. Check Package.swift resources declaration.")
      return []
    }

    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode([Exercise].self, from: data)
    } catch {
      assertionFailure("Bundled catalog v2 decode failed: \(error)")
      return []
    }
  }

  static func syntheticCompetitionLifts() -> [Exercise] {
    let now = Date()
    return [
      Exercise(
        id: uuid(20),
        name: "比赛式深蹲",
        nameEn: "Competition Squat",
        exerciseType: .mainLift,
        mainLiftFamily: .squat,
        isCompetitionLift: true,
        muscleGroups: [.quad, .glute],
        equipment: [.barbell],
        movementPattern: [.squat],
        createdAt: now
      ),
      Exercise(
        id: uuid(21),
        name: "比赛式卧推",
        nameEn: "Competition Bench Press",
        exerciseType: .mainLift,
        mainLiftFamily: .bench,
        isCompetitionLift: true,
        muscleGroups: [.chest, .triceps],
        equipment: [.barbell],
        movementPattern: [.horizontalPush],
        createdAt: now
      ),
      Exercise(
        id: uuid(22),
        name: "比赛式传统硬拉",
        nameEn: "Competition Conventional Deadlift",
        exerciseType: .mainLift,
        mainLiftFamily: .deadlift,
        isCompetitionLift: true,
        muscleGroups: [.back, .hamstring],
        equipment: [.barbell],
        movementPattern: [.hipHinge],
        createdAt: now
      ),
      Exercise(
        id: uuid(23),
        name: "比赛式相扑硬拉",
        nameEn: "Competition Sumo Deadlift",
        exerciseType: .mainLift,
        mainLiftFamily: .deadlift,
        isCompetitionLift: true,
        muscleGroups: [.back, .hamstring, .glute],
        equipment: [.barbell],
        movementPattern: [.hipHinge],
        createdAt: now
      ),
    ]
  }

  private static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }
}
// swiftlint:enable type_body_length
