import CoreModels
import Foundation

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
      id: UUID(),
      userID: UUID(),
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
      id: UUID(),
      userID: UUID(),
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
      id: UUID(),
      userID: UUID(),
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
      id: UUID(),
      userID: UUID(),
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

  private static func previewCatalog() -> [Exercise] {
    let now = Date()
    return [
      Exercise(
        id: UUID(),
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
        id: UUID(),
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
        id: UUID(),
        name: "竞技硬拉",
        exerciseType: .mainLift,
        mainLiftFamily: .deadlift,
        isCompetitionLift: true,
        muscleGroups: [.back, .hamstring],
        equipment: [.barbell],
        movementPattern: [.pull],
        createdAt: now
      ),
    ]
  }
}
