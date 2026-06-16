import CoreModels
import Foundation
import Networking
import RepositoryContracts

public actor BackendStudentPlanRepository: StudentPlanRepository {
  private let api: APIClient
  private let session: any SessionStateReader
  private let cache: StudentPlanCache
  private var catalog: [UUID: Exercise] = [:]

  public init(
    api: APIClient,
    session: any SessionStateReader,
    cache: StudentPlanCache = StudentPlanCache()
  ) {
    self.api = api
    self.session = session
    self.cache = cache
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

  public func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    guard let plan = try await fetchCurrentPlan(studentID: studentID) else {
      return nil
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    return plan.days.first { calendar.isDate($0.date, inSameDayAs: date) }
  }

  public func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    guard let plan = try await fetchCurrentPlan(studentID: studentID) else {
      return []
    }
    return plan.days.sorted { $0.date < $1.date }
  }

  @discardableResult
  private func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    let token = try await session.accessToken()
    let response = try await api.studentPlans(
      studentID: studentID,
      status: [.published],
      accessToken: token
    )
    guard
      let plan = response.plans.sorted(by: { $0.startDate > $1.startDate }).first
    else {
      return nil
    }

    let tree = try await api.plan(id: plan.id, accessToken: token).toDomain()
    let exercises = try await exerciseCatalog(accessToken: token)
    let projection = StudentPlanProjection.project(
      tree: tree,
      catalog: exercises,
      weekIndex: Self.currentWeekIndex(for: tree.plan)
    )
    try await cache.save(plan: projection, studentID: studentID)
    return projection
  }

  private func exerciseCatalog(accessToken: String) async throws -> [Exercise] {
    if !catalog.isEmpty {
      return Array(catalog.values)
    }
    let response = try await api.exercises(accessToken: accessToken)
    catalog = Dictionary(
      response.exercises.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    return response.exercises
  }

  private static func currentWeekIndex(for plan: TrainingPlan) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let start = calendar.startOfDay(for: plan.startDate)
    let today = calendar.startOfDay(for: Date())
    let elapsedDays = calendar.dateComponents([.day], from: start, to: today).day ?? 0
    let week = max(1, elapsedDays / 7 + 1)
    return min(week, plan.planWeeks)
  }
}

private enum StudentPlanProjection {
  static func project(
    tree: TrainingPlanTree,
    catalog: [Exercise],
    weekIndex: Int
  ) -> StudentPlanView {
    let exerciseByID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    let exercisesByDay = Dictionary(grouping: tree.exercises, by: \.planDayID)
    let setsByExercise = Dictionary(grouping: tree.sets, by: \.planExerciseID)
    // Project the WHOLE cycle (all weeks), not just the current week: the
    // training-tab calendar and history both navigate across weeks, and
    // fetchDay(date:) must resolve any cycle day. Consumers that want only the
    // current week (e.g. the dashboard week strip) filter by date themselves.
    let days =
      tree.days
      .sorted { lhs, rhs in
        if lhs.dayOfWeek == rhs.dayOfWeek { return lhs.sortOrder < rhs.sortOrder }
        return lhs.dayOfWeek < rhs.dayOfWeek
      }
      .map { day in
        studentDay(
          day,
          startDate: tree.plan.startDate,
          planExercises: exercisesByDay[day.id] ?? [],
          setsByExercise: setsByExercise,
          exerciseByID: exerciseByID
        )
      }

    return StudentPlanView(
      cycleID: tree.plan.id,
      weekIndex: weekIndex,
      startDate: tree.plan.startDate,
      planKind: tree.plan.kind,
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
            .map(prescribedSet)
        )
      }
    return StudentPlanDay(
      id: day.id,
      date: date(for: day, startDate: startDate),
      exercises: exercises
    )
  }

  private static func prescribedSet(_ planSet: PlanSet) -> PrescribedSet {
    let isRange = planSet.targetRepsMax != nil
    return PrescribedSet(
      id: planSet.id,
      setIndex: planSet.setNumber,
      weightKg: planSet.intensityMode == .weight ? planSet.targetValue : nil,
      reps: isRange ? nil : planSet.targetReps,
      repsMax: planSet.targetRepsMax,
      rpe: planSet.intensityMode == .rpe ? planSet.targetValue : nil,
      restSeconds: planSet.restSeconds
    )
  }

  private static func date(for day: PlanDay, startDate: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let offset = (day.weekNumber - 1) * 7 + (day.dayOfWeek - 1)
    return calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
  }
}
