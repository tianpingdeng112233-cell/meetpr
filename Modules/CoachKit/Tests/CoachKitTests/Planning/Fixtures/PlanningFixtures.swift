import CoreModels
import Foundation

@testable import CoachKit

// swiftlint:disable type_body_length
@available(iOS 17.0, macOS 14.0, *)
enum PlanningFixtures {
  static let now = Date(timeIntervalSince1970: 1_766_630_400)
  static let planID = uuid(1)
  static let coachID = uuid(2)
  static let evaluationStudentID = uuid(10)
  static let activeStudentID = uuid(11)
  static let secondActiveStudentID = uuid(12)
  static let abnormalStudentID = uuid(13)
  static let squatID = uuid(30)
  static let benchID = uuid(31)
  static let deadliftID = uuid(32)
  static let pauseSquatID = uuid(33)
  static let pauseBenchID = uuid(34)
  static let tempoDeadliftID = uuid(35)
  static let frontSquatID = uuid(36)
  static let accessoryID = uuid(37)
  static let barbellLungeID = uuid(38)
  static let pullUpID = uuid(39)
  static let dumbbellCurlID = uuid(41)
  static let cablePushdownID = uuid(42)

  static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }

  static func students() -> [CoachStudentSummary] {
    [
      CoachStudentSummary(
        id: evaluationStudentID,
        profile: profile(id: uuid(100), userID: evaluationStudentID, days: [2, 4, 6]),
        displayName: "王小明",
        status: .inEvaluation(remainingDays: 4, remainingHours: 13)
      ),
      CoachStudentSummary(
        id: activeStudentID,
        profile: profile(id: uuid(101), userID: activeStudentID, days: [1, 3, 5, 6]),
        displayName: "张三",
        status: .active
      ),
      CoachStudentSummary(
        id: secondActiveStudentID,
        profile: profile(id: uuid(102), userID: secondActiveStudentID, days: [1, 2, 4, 6]),
        displayName: "李四",
        status: .active
      ),
      CoachStudentSummary(
        id: abnormalStudentID,
        profile: profile(id: uuid(103), userID: abnormalStudentID, days: [1, 3, 5]),
        displayName: "钱六",
        status: .abnormal(reason: .noTrainingForDays(3))
      ),
    ]
  }

  static func catalog() -> [Exercise] {
    [
      exercise(id: squatID, name: "比赛式深蹲", type: .mainLift, family: .squat),
      exercise(
        id: benchID,
        name: "比赛式卧推",
        type: .mainLift,
        family: .bench,
        movementPattern: [.horizontalPush]
      ),
      exercise(
        id: deadliftID,
        name: "比赛式传统硬拉",
        type: .mainLift,
        family: .deadlift,
        movementPattern: [.hipHinge]
      ),
      exercise(id: pauseSquatID, name: "暂停深蹲", type: .mainLiftVariation, family: .squat),
      exercise(
        id: pauseBenchID,
        name: "暂停卧推",
        type: .mainLiftVariation,
        family: .bench,
        movementPattern: [.horizontalPush]
      ),
      exercise(
        id: tempoDeadliftID,
        name: "节奏硬拉",
        type: .mainLiftVariation,
        family: .deadlift,
        movementPattern: [.hipHinge]
      ),
      exercise(id: frontSquatID, name: "前蹲举", type: .mainLiftVariation, family: .squat),
    ] + accessoryCatalog()
  }

  static func accessoryCatalog() -> [Exercise] {
    [
      exercise(
        id: accessoryID,
        name: "哈克深蹲",
        type: .accessory,
        family: nil,
        muscleGroups: [.quad],
        equipment: [.machine],
        movementPattern: [.squat]
      ),
      exercise(
        id: barbellLungeID,
        name: "杠铃箭步蹲",
        type: .accessory,
        family: nil,
        muscleGroups: [.quad, .glute],
        equipment: [.barbell],
        movementPattern: [.squat]
      ),
      exercise(
        id: pullUpID,
        name: "引体向上",
        type: .accessory,
        family: nil,
        muscleGroups: [.back, .biceps],
        equipment: [.bodyweight],
        movementPattern: [.verticalPull]
      ),
      exercise(
        id: dumbbellCurlID,
        name: "哑铃弯举",
        type: .accessory,
        family: nil,
        muscleGroups: [.biceps],
        equipment: [.dumbbell],
        movementPattern: [.other]
      ),
      exercise(
        id: cablePushdownID,
        name: "三头绳索下压",
        type: .accessory,
        family: nil,
        muscleGroups: [.triceps],
        equipment: [.cable],
        movementPattern: [.other]
      ),
    ]
  }

  static func repository() -> InMemoryPlanRepository {
    InMemoryPlanRepository(students: students(), catalog: catalog())
  }

  @MainActor
  static func store(stateDefaults: UserDefaults? = nil) throws -> DraftStore {
    try DraftStore.inMemory(stateDefaults: stateDefaults)
  }

  @MainActor
  static func viewModel() throws -> PlanningViewModel {
    try PlanningViewModel(repository: repository(), draftStore: store())
  }

  @MainActor
  static func configuredViewModelForStep3() async throws -> PlanningViewModel {
    let viewModel = try viewModel()
    await viewModel.bootstrap()
    viewModel.selectStudent(students()[1])
    viewModel.selectDuration(4)
    viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 1, deadlift: 1)
    viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
    viewModel.toggleAssignment(dayOfWeek: 3, liftFamily: .bench)
    viewModel.toggleAssignment(dayOfWeek: 5, liftFamily: .deadlift)
    return viewModel
  }

  @MainActor
  static func draft() -> DraftTrainingPlan {
    let draft = DraftTrainingPlan(
      id: planID,
      traineeID: activeStudentID,
      coachID: coachID,
      name: "张三 4 周计划",
      startDate: now,
      endDate: now.addingTimeInterval(2_332_800),
      planWeeks: 4,
      currentStepRawValue: PlanningStep.selectMainLifts.rawValue,
      lastSavedAt: now
    )
    let day = DraftPlanDay(
      id: uuid(40),
      dayOfWeek: 1,
      sortOrder: 0,
      assignedLiftFamilyRawValues: [LiftFamily.squat.rawValue],
      plan: draft
    )
    let exercise = DraftPlanExercise(
      id: uuid(50),
      exerciseID: squatID,
      isMainLift: true,
      sortOrder: 0,
      day: day
    )
    day.draftExercises = [exercise]
    draft.draftDays = [day]
    return draft
  }

  static func plan() -> TrainingPlan {
    TrainingPlan(
      id: planID,
      coachID: coachID,
      traineeID: activeStudentID,
      name: "张三 4 周计划",
      startDate: now,
      endDate: now.addingTimeInterval(2_332_800),
      planWeeks: 4,
      source: .coach,
      status: .draft,
      createdAt: now,
      updatedAt: now
    )
  }

  static func planDays() -> [PlanDay] {
    [
      PlanDay(id: uuid(40), planID: planID, dayOfWeek: 1, weekNumber: 1, sortOrder: 0)
    ]
  }

  static func planExercises() -> [PlanExercise] {
    [
      PlanExercise(
        id: uuid(50),
        planDayID: uuid(40),
        exerciseID: squatID,
        isMainLift: true,
        sortOrder: 0,
        notes: "主项"
      )
    ]
  }

  private static func profile(id: UUID, userID: UUID, days: [Int]) -> StudentProfile {
    StudentProfile(
      id: id,
      userID: userID,
      trainingMode: .coached,
      trainingYears: 3,
      squatStance: .lowBar,
      deadliftStance: .conventional,
      benchGrip: .standard,
      currentSquat1RM: Decimal(180),
      bench1RM: Decimal(120),
      deadlift1RM: Decimal(220),
      trainingDaysOfWeek: days,
      gymTier: .commercial,
      dailyIntensityLevel: 3,
      lifeStressLevel: 3,
      recoverySpeed: 4,
      sleepHours: 7,
      musclesToStrengthen: ["股四", "腘绳", "肩"],
      competitionTargeting: false,
      createdAt: now,
      updatedAt: now
    )
  }

  private static func exercise(
    id: UUID,
    name: String,
    type: ExerciseType,
    family: LiftFamily?,
    muscleGroups: [MuscleGroup] = [.quad],
    equipment: [Equipment] = [.barbell],
    movementPattern: [MovementPattern] = [.squat]
  ) -> Exercise {
    Exercise(
      id: id,
      name: name,
      exerciseType: type,
      mainLiftFamily: family,
      isCompetitionLift: type == .mainLift,
      muscleGroups: muscleGroups,
      equipment: equipment,
      movementPattern: movementPattern,
      createdAt: now
    )
  }
}
// swiftlint:enable type_body_length
