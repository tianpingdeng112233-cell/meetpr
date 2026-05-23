import CoreModels
import Foundation
import Networking

public enum BackendPlanRepositoryError: Error, Equatable, Sendable {
  case missingServerDayID(localDayID: UUID)
  case missingServerExerciseID(localExerciseID: UUID)
}

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
        id: dto.userID,
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

    let children = try await createPlanChildren(
      planID: created.id,
      days: days,
      exercises: exercises,
      sets: sets,
      accessToken: token
    )
    let published = try await api.publishPlan(id: created.id, accessToken: token)
    let tree = TrainingPlanTree(
      plan: published.toDomain(),
      days: children.days.map { $0.toDomain() },
      exercises: children.exercises.map { $0.toDomain() },
      sets: children.sets.map { $0.toDomain() }
    )
    try await cache.save(plan: tree)
  }

  private func createPlanChildren(
    planID: UUID,
    days: [PlanDay],
    exercises: [PlanExercise],
    sets: [PlanSet],
    accessToken: String
  ) async throws -> CreatedPlanChildren {
    let daysResult = try await createDays(days, planID: planID, accessToken: accessToken)
    let exercisesResult = try await createExercises(
      exercises,
      serverDayIDs: daysResult.serverIDs,
      accessToken: accessToken
    )
    let createdSets = try await createSets(
      sets,
      serverExerciseIDs: exercisesResult.serverIDs,
      accessToken: accessToken
    )

    return CreatedPlanChildren(
      days: daysResult.values,
      exercises: exercisesResult.values,
      sets: createdSets
    )
  }

  private func createDays(
    _ days: [PlanDay],
    planID: UUID,
    accessToken: String
  ) async throws -> CreatedPlanDays {
    var serverDayIDs: [UUID: UUID] = [:]
    var createdDays: [PlanDayDTO] = []
    for day in days {
      let createdDay = try await api.createPlanDay(
        planID: planID,
        CreatePlanDayRequestDTO(
          dayOfWeek: day.dayOfWeek,
          weekNumber: day.weekNumber,
          sortOrder: day.sortOrder
        ),
        accessToken: accessToken
      )
      serverDayIDs[day.id] = createdDay.id
      createdDays.append(createdDay)
    }

    return CreatedPlanDays(serverIDs: serverDayIDs, values: createdDays)
  }

  private func createExercises(
    _ exercises: [PlanExercise],
    serverDayIDs: [UUID: UUID],
    accessToken: String
  ) async throws -> CreatedPlanExercises {
    var serverExerciseIDs: [UUID: UUID] = [:]
    var createdExercises: [PlanExerciseDTO] = []
    for exercise in exercises {
      guard let serverDayID = serverDayIDs[exercise.planDayID] else {
        throw BackendPlanRepositoryError.missingServerDayID(localDayID: exercise.planDayID)
      }

      let createdExercise = try await api.createPlanExercise(
        dayID: serverDayID,
        CreatePlanExerciseRequestDTO(
          exerciseID: exercise.exerciseID,
          isMainLift: exercise.isMainLift,
          sortOrder: exercise.sortOrder,
          notes: exercise.notes
        ),
        accessToken: accessToken
      )
      serverExerciseIDs[exercise.id] = createdExercise.id
      createdExercises.append(createdExercise)
    }

    return CreatedPlanExercises(serverIDs: serverExerciseIDs, values: createdExercises)
  }

  private func createSets(
    _ sets: [PlanSet],
    serverExerciseIDs: [UUID: UUID],
    accessToken: String
  ) async throws -> [PlanSetDTO] {
    var createdSets: [PlanSetDTO] = []
    for set in sets {
      guard let serverExerciseID = serverExerciseIDs[set.planExerciseID] else {
        throw BackendPlanRepositoryError.missingServerExerciseID(
          localExerciseID: set.planExerciseID
        )
      }

      let createdSet = try await api.createPlanSet(
        planExerciseID: serverExerciseID,
        CreatePlanSetRequestDTO(
          setNumber: set.setNumber,
          targetReps: set.targetReps,
          targetRepsMax: set.targetRepsMax,
          intensityMode: set.intensityMode,
          targetValue: set.targetValue,
          setType: set.setType
        ),
        accessToken: accessToken
      )
      createdSets.append(createdSet)
    }

    return createdSets
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

private struct CreatedPlanChildren: Sendable {
  let days: [PlanDayDTO]
  let exercises: [PlanExerciseDTO]
  let sets: [PlanSetDTO]
}

private struct CreatedPlanDays: Sendable {
  let serverIDs: [UUID: UUID]
  let values: [PlanDayDTO]
}

private struct CreatedPlanExercises: Sendable {
  let serverIDs: [UUID: UUID]
  let values: [PlanExerciseDTO]
}
