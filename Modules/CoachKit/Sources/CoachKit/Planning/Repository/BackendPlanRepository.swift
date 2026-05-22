import CoreModels
import Foundation
import Networking

public actor BackendPlanRepository: PlanRepository {
  private let api: APIClient
  private let session: any SessionStateReader
  private let cache: PlanCache
  private var catalog: [Exercise] = []

  public init(api: APIClient, session: any SessionStateReader, cache: PlanCache = PlanCache()) {
    self.api = api
    self.session = session
    self.cache = cache
  }

  public func fetchStudents() async throws -> [CoachStudentSummary] {
    let token = try await session.accessToken()
    let response = try await api.coachStudents(accessToken: token)
    return response.students.map { dto in
      CoachStudentSummary(
        id: dto.id,
        profile: dto.profile,
        displayName: dto.displayName,
        status: Self.status(from: dto.status)
      )
    }
  }

  public func fetchMainLiftCatalog() async throws -> [Exercise] {
    let token = try await session.accessToken()
    async let mainLifts = api.exercises(type: .mainLift, accessToken: token).exercises
    async let variations = api.exercises(type: .mainLiftVariation, accessToken: token).exercises
    let exercises = try await mainLifts + variations
    catalog = mergeCatalog(exercises)
    return exercises.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  public func fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise] {
    let token = try await session.accessToken()
    let exercises = try await api.exercises(type: .accessory, accessToken: token).exercises
    catalog = mergeCatalog(exercises)
    return Self.filterAccessories(exercises, filters: filters)
  }

  public func publishPlan(
    plan: TrainingPlan,
    days: [PlanDay],
    exercises: [PlanExercise],
    sets: [PlanSet]
  ) async throws {
    let token = try await session.accessToken()
    let created = try await api.createPlan(
      CreatePlanRequestDTO(
        traineeID: plan.traineeID,
        name: plan.name,
        startDate: plan.startDate,
        endDate: plan.endDate,
        planWeeks: plan.planWeeks,
        source: plan.source,
        sourceTemplateID: plan.sourceTemplateID
      ),
      accessToken: token
    )
    let published = try await api.publishPlan(id: created.id, accessToken: token)
    let tree = TrainingPlanTree(
      plan: published.toDomain(),
      days: days.map { day in
        PlanDay(
          id: day.id,
          planID: published.id,
          dayOfWeek: day.dayOfWeek,
          weekNumber: day.weekNumber,
          sortOrder: day.sortOrder
        )
      },
      exercises: exercises,
      sets: sets
    )
    try await cache.save(plan: tree)
  }

  private func mergeCatalog(_ exercises: [Exercise]) -> [Exercise] {
    let existing = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    let incoming = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    return Array(existing.merging(incoming) { _, new in new }.values)
  }

  private static func filterAccessories(
    _ exercises: [Exercise],
    filters: AccessoryFilters
  ) -> [Exercise] {
    exercises
      .filter { exercise in
        guard exercise.exerciseType == .accessory else { return false }
        let missesMuscleGroup =
          !filters.muscleGroups.isEmpty
          && Set(exercise.muscleGroups).isDisjoint(with: filters.muscleGroups)
        if missesMuscleGroup { return false }

        let missesEquipment =
          !filters.equipment.isEmpty
          && Set(exercise.equipment).isDisjoint(with: filters.equipment)
        if missesEquipment { return false }

        let missesMovementPattern =
          !filters.movementPatterns.isEmpty
          && Set(exercise.movementPattern).isDisjoint(with: filters.movementPatterns)
        if missesMovementPattern { return false }

        return true
      }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private static func status(from rawValue: String) -> CoachStudentStatus {
    switch rawValue {
    case "evaluating", "pending":
      return .inEvaluation(remainingDays: 0, remainingHours: 0)
    case "active", "accepted":
      return .active
    default:
      return .active
    }
  }
}
