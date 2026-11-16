import CoreModels
import Foundation
import Networking
import RepositoryContracts

public actor BackendStudentPlanRepository: StudentPlanRepository, ExerciseCatalogReading {
  private let api: APIClient
  private let session: any SessionStateReader
  private let cache: StudentPlanCache
  private let catalogCache: ExerciseCatalogCache
  private var catalog: [UUID: Exercise] = [:]
  private var catalogRefreshTask: Task<[Exercise], any Error>?
  private var planRefreshTasks: [UUID: Task<StudentPlanView?, any Error>] = [:]

  public init(
    api: APIClient,
    session: any SessionStateReader,
    cache: StudentPlanCache = StudentPlanCache(),
    catalogCache: ExerciseCatalogCache = ExerciseCatalogCache(),
    calendar: Calendar = .current,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.api = api
    self.session = session
    self.cache = cache
    self.catalogCache = catalogCache
    _ = calendar
    _ = now
  }

  public func weightSuggestions(studentID: UUID, dayID: UUID) async throws
    -> [SetWeightSuggestionRecord]
  {
    let token = try await session.accessToken()
    return try await api.weightSuggestions(studentID: studentID, dayID: dayID, accessToken: token)
  }

  public func fetchPlan(id: UUID, studentID: UUID) async throws -> StudentPlanView? {
    let token = try await session.accessToken()
    let tree = try await api.plan(id: id, accessToken: token).toDomain()
    guard tree.plan.traineeID == studentID else { return nil }
    let exercises = try await exerciseCatalog(accessToken: token)
    return StudentPlanProjection.project(tree: tree, catalog: exercises, weekIndex: 1)
  }

  public func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    do {
      return try await refreshCurrentPlan(studentID: studentID)
    } catch {
      if error.isTaskCancellation { throw error }
      if let cached = await cache.loadPlan(studentID: studentID) { return cached }
      throw error
    }
  }

  public func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    try await refreshCurrentPlanFromBackend(studentID: studentID)
  }

  public func fetchDay(studentID: UUID, dayID: UUID) async throws -> StudentPlanDay? {
    guard let plan = try await fetchCurrentPlan(studentID: studentID) else {
      return nil
    }
    return plan.days.first { $0.id == dayID }
  }

  public func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    guard let plan = try await fetchCurrentPlan(studentID: studentID) else {
      return []
    }
    return StudentPlanSequence.orderedDays(in: plan)
  }

  public func fetchExerciseCatalog() async throws -> [Exercise] {
    let accessToken = try await session.accessToken()
    return try await exerciseCatalog(accessToken: accessToken)
  }

  public func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    let token = try await session.accessToken()
    do {
      let completion = try await api.completePlanDay(id: id, accessToken: token)
      await updateCachedCompletion(
        dayID: id,
        completedAt: completion.completedAt,
        source: completion.source,
        studentID: studentID
      )
      return PlanDayCompletion(
        id: completion.id,
        dayID: completion.planDayID,
        studentID: completion.studentID,
        source: completion.source,
        completedAt: completion.completedAt
      )
    } catch {
      throw Self.completionError(from: error)
    }
  }

  public func undoDayCompletion(id: UUID, studentID: UUID) async throws {
    let token = try await session.accessToken()
    do {
      try await api.undoPlanDayCompletion(id: id, accessToken: token)
    } catch {
      if BackendErrorEnvelope.machineCode(from: error) != "NO_COMPLETION_TO_UNDO" {
        throw Self.completionError(from: error)
      }
    }
    await updateCachedCompletion(
      dayID: id,
      completedAt: nil,
      source: nil,
      studentID: studentID
    )
  }

  @discardableResult
  private func refreshCurrentPlanFromBackend(studentID: UUID) async throws -> StudentPlanView? {
    if let task = planRefreshTasks[studentID] {
      return try await task.value
    }
    let task: Task<StudentPlanView?, any Error> = Task { [weak self] in
      guard let self else { return nil }
      return try await self.performPlanRefresh(studentID: studentID)
    }
    planRefreshTasks[studentID] = task
    defer { planRefreshTasks[studentID] = nil }
    return try await task.value
  }

  private func performPlanRefresh(studentID: UUID) async throws -> StudentPlanView? {
    let token = try await session.accessToken()
    let planID: UUID?
    let handoff: StudentPlanHandoff?
    do {
      let response = try await api.planHandoff(studentID: studentID, accessToken: token)
      planID = response.currentPlanID
      handoff = response.handoff
    } catch {
      if error.isTaskCancellation { throw error }
      handoff = nil
      // Compatibility only, including a server that has not deployed /plan-handoff yet.
      let response = try await api.studentPlans(
        studentID: studentID, status: [.published], accessToken: token)
      planID =
        response.plans.max {
          if $0.publishedAt != $1.publishedAt {
            return ($0.publishedAt ?? .distantPast) < ($1.publishedAt ?? .distantPast)
          }
          if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
          return $0.id.uuidString < $1.id.uuidString
        }?.id
    }
    guard let planID else {
      await cache.removePlan(studentID: studentID)
      return nil
    }

    let tree = try await api.plan(id: planID, accessToken: token).toDomain()
    let exercises = try await exerciseCatalog(accessToken: token)
    var projection = StudentPlanProjection.project(
      tree: tree,
      catalog: exercises,
      weekIndex: 1
    )
    projection.handoff =
      handoff
      ?? StudentPlanHandoff(
        currentPlanID: projection.cycleID,
        plans: [
          .init(
            id: projection.cycleID, name: tree.plan.name, weeks: tree.plan.planWeeks,
            completedTrainingDays: projection.days.filter { $0.completedAt != nil }.count,
            totalTrainingDays: projection.days.count, status: .current)
        ])
    try await cache.save(plan: projection, studentID: studentID)
    return projection
  }

  private func exerciseCatalog(accessToken: String) async throws -> [Exercise] {
    if !catalog.isEmpty {
      return Array(catalog.values)
    }
    if let catalogRefreshTask {
      return try await catalogRefreshTask.value
    }
    let task: Task<[Exercise], any Error> = Task { [weak self] in
      guard let self else { return [] }
      return try await self.loadExerciseCatalog(accessToken: accessToken)
    }
    catalogRefreshTask = task
    defer { catalogRefreshTask = nil }
    let exercises = try await task.value
    catalog = Dictionary(
      exercises.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    return exercises
  }

  private func loadExerciseCatalog(accessToken: String) async throws -> [Exercise] {
    let cached = await catalogCache.load()
    let response = try await api.exerciseCatalogResponse(
      ifNoneMatch: cached?.etag,
      accessToken: accessToken
    )
    let exercises: [Exercise]
    if response.statusCode == 304, let cached {
      exercises = cached.exercises
    } else {
      let decoded = try MeetPRCodec.decoder.decode(
        ExercisesResponseDTO.self,
        from: response.data
      )
      exercises = decoded.exercises
      try await catalogCache.save(
        exercises: exercises,
        etag: response.headerValue(for: "ETag")
      )
    }
    return exercises
  }

  private func updateCachedCompletion(
    dayID: UUID,
    completedAt: Date?,
    source: String?,
    studentID: UUID
  ) async {
    guard let plan = await cache.loadPlan(studentID: studentID) else { return }
    let updatedDays = plan.days.map { day in
      guard day.id == dayID else { return day }
      return StudentPlanDay(
        id: day.id,
        weekNumber: day.weekNumber,
        dayOfWeek: day.dayOfWeek,
        sortOrder: day.sortOrder,
        date: day.scheduledDate,
        shiftedToDate: day.shiftedToDate,
        completedAt: completedAt,
        completionSource: source,
        exercises: day.exercises
      )
    }
    let updated = StudentPlanView(
      cycleID: plan.cycleID,
      handoff: plan.handoff,
      weekIndex: plan.weekIndex,
      startDate: plan.startDate,
      endDate: plan.endDate,
      planKind: plan.planKind,
      publishedAt: plan.publishedAt,
      totalShiftDays: plan.totalShiftDays,
      latestShiftCreatedAt: plan.latestShiftCreatedAt,
      days: updatedDays
    )
    try? await cache.save(plan: updated, studentID: studentID)
  }

  private static func completionError(from error: any Error) -> any Error {
    PlanDayCompletionError(machineCode: BackendErrorEnvelope.machineCode(from: error)) ?? error
  }

}
