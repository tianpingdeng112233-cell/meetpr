import CoreModels
import Foundation
import RepositoryContracts

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

  public static func preview(store: (any StudentPlanStore)?) -> InMemoryPlanRepository {
    InMemoryPlanRepository(
      students: previewStudents(),
      catalog: previewCatalog(),
      store: store
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

  private static func previewStudents() -> [CoachStudentSummary] {
    return [
      CoachStudentSummary(
        id: uuid(4),
        displayName: "王晨曦",
        status: .active
      ),
      CoachStudentSummary(
        id: uuid(2),
        displayName: "张以恒",
        status: .active
      ),
      CoachStudentSummary(
        id: uuid(8),
        displayName: "李嘉宁",
        status: .active
      ),
      CoachStudentSummary(
        id: uuid(10),
        displayName: "赵安然",
        status: .active
      ),
      CoachStudentSummary(
        id: uuid(6),
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
    return competitionLiftSeeds.map { seed in
      Exercise(
        id: seed.id,
        name: seed.name,
        nameEn: seed.nameEn,
        exerciseType: .mainLift,
        mainLiftFamily: seed.mainLiftFamily,
        isCompetitionLift: true,
        muscleGroups: seed.muscleGroups,
        equipment: [.barbell],
        movementPattern: seed.movementPattern,
        createdAt: now
      )
    }
  }

  fileprivate static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }
}

private struct CompetitionLiftSeed {
  let id: UUID
  let name: String
  let nameEn: String
  let mainLiftFamily: LiftFamily
  let muscleGroups: [MuscleGroup]
  let movementPattern: [MovementPattern]
}

private let competitionLiftSeeds = [
  CompetitionLiftSeed(
    id: InMemoryPlanRepository.uuid(20),
    name: "比赛式深蹲",
    nameEn: "Competition Squat",
    mainLiftFamily: .squat,
    muscleGroups: [.quad, .glute],
    movementPattern: [.squat]
  ),
  CompetitionLiftSeed(
    id: InMemoryPlanRepository.uuid(21),
    name: "比赛式卧推",
    nameEn: "Competition Bench Press",
    mainLiftFamily: .bench,
    muscleGroups: [.chest, .triceps],
    movementPattern: [.horizontalPush]
  ),
  CompetitionLiftSeed(
    id: InMemoryPlanRepository.uuid(22),
    name: "比赛式传统硬拉",
    nameEn: "Competition Conventional Deadlift",
    mainLiftFamily: .deadlift,
    muscleGroups: [.back, .hamstring],
    movementPattern: [.hipHinge]
  ),
  CompetitionLiftSeed(
    id: InMemoryPlanRepository.uuid(23),
    name: "比赛式相扑硬拉",
    nameEn: "Competition Sumo Deadlift",
    mainLiftFamily: .deadlift,
    muscleGroups: [.back, .hamstring, .glute],
    movementPattern: [.hipHinge]
  ),
]
