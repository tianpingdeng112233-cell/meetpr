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

  public func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    if let cached = await cache.loadPlan(studentID: studentID) {
      Task { [weak self] in
        try? await self?.refreshCurrentPlan(studentID: studentID)
      }
      return cached
    }
    return try await refreshCurrentPlan(studentID: studentID)
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
    let response = try await api.studentPlans(
      studentID: studentID,
      status: [.published],
      accessToken: token
    )
    guard
      let plan = response.plans.max(by: Self.planPrecedes)
    else {
      return nil
    }

    let tree = try await api.plan(id: plan.id, accessToken: token).toDomain()
    let exercises = try await exerciseCatalog(accessToken: token)
    let projection = StudentPlanProjection.project(
      tree: tree,
      catalog: exercises,
      weekIndex: 1
    )
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

  /// Current-plan selection from backend spec 035: max publishedAt, then
  /// createdAt, then id. The list endpoint's createdAt ordering is legacy only.
  static func planPrecedes(_ lhs: PlanDTO, _ rhs: PlanDTO) -> Bool {
    let lhsPublishedAt = lhs.publishedAt ?? .distantPast
    let rhsPublishedAt = rhs.publishedAt ?? .distantPast
    if lhsPublishedAt != rhsPublishedAt { return lhsPublishedAt < rhsPublishedAt }
    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
    return lhs.id.uuidString < rhs.id.uuidString
  }

}

/// `internal` (not `private`) so `@testable` unit tests can exercise the
/// projection directly — notably the coachNote passthrough (spec 043 §G).
enum StudentPlanProjection {
  static func project(
    tree: TrainingPlanTree,
    catalog: [Exercise],
    weekIndex: Int
  ) -> StudentPlanView {
    let exerciseByID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    let exercisesByDay = Dictionary(grouping: tree.exercises, by: \.planDayID)
    let setsByExercise = Dictionary(grouping: tree.sets, by: \.planExerciseID)
    // Project the WHOLE cycle (all weeks), not just the current week: the
    // Student sequence and history both navigate the complete published cycle.
    let days =
      tree.days.map { day in
        studentDay(
          day,
          startDate: tree.plan.startDate,
          planExercises: exercisesByDay[day.id] ?? [],
          setsByExercise: setsByExercise,
          exerciseByID: exerciseByID
        )
      }
      .sorted(by: StudentPlanSequence.precedes)

    return StudentPlanView(
      cycleID: tree.plan.id,
      weekIndex: days.first(where: { $0.completedAt == nil })?.weekNumber
        ?? days.last?.weekNumber
        ?? weekIndex,
      startDate: tree.plan.startDate,
      endDate: tree.plan.endDate,
      planKind: tree.plan.kind,
      publishedAt: tree.plan.publishedAt,
      totalShiftDays: tree.plan.totalShiftDays,
      latestShiftCreatedAt: tree.plan.latestShiftCreatedAt,
      days: days
    )
  }

  private static func studentDay(
    _ day: PlanDay,
    startDate: Date,
    planExercises: [PlanExercise],
    setsByExercise: [UUID: [PlanSet]],
    exerciseByID: [UUID: Exercise]
  ) -> StudentPlanDay {
    let exercises =
      planExercises
      .sorted { $0.sortOrder < $1.sortOrder }
      .compactMap { planExercise -> StudentPlanExercise? in
        guard let exercise = exerciseByID[planExercise.exerciseID] else { return nil }
        return StudentPlanExercise(
          id: planExercise.id,
          exercise: exercise,
          sequenceIndex: planExercise.sortOrder,
          prescribedSets: (setsByExercise[planExercise.id] ?? [])
            .sorted { $0.setNumber < $1.setNumber }
            .compactMap(prescribedSet),
          notes: planExercise.notes
        )
      }
    return StudentPlanDay(
      id: day.id,
      weekNumber: day.weekNumber,
      dayOfWeek: day.dayOfWeek,
      sortOrder: day.sortOrder,
      date: scheduledDate(for: day, startDate: startDate),
      shiftedToDate: day.shiftedToDate,
      completedAt: day.completedAt,
      completionSource: day.completionSource,
      exercises: exercises
    )
  }

  /// Returns nil for a corrupt planning row (`setNumber < 1`). Clamping instead would fold
  /// plan sets [0, 1] into execution index [0, 0], and the execution layer keys logs by
  /// (planExerciseID, setIndex) — two cards would silently share one log and the later set
  /// would overwrite the earlier. Dropping the corrupt set keeps every legal set's identity.
  private static func prescribedSet(_ planSet: PlanSet) -> PrescribedSet? {
    guard planSet.setNumber >= 1 else { return nil }
    return PrescribedSet(
      id: planSet.id,
      setIndex: planSet.setNumber - 1,
      weightKg: planSet.intensityMode == .weight ? planSet.targetValue : nil,
      reps: planSet.targetReps,
      repsMax: planSet.targetRepsMax,
      rpe:
        planSet.intensityMode == .rpe && planSet.loadMode != "pct"
        ? planSet.targetValue : nil,
      restSeconds: planSet.restSeconds,
      coachNote: planSet.coachNote
    )
  }

  private static func scheduledDate(for day: PlanDay, startDate: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let offset = (day.weekNumber - 1) * 7 + (day.dayOfWeek - 1)
    return calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
  }
}
