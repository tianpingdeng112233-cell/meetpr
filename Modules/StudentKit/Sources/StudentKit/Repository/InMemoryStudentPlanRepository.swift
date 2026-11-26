import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryStudentPlanRepository: StudentPlanRepository {
  private static let completionUndoWindow: TimeInterval = 7 * 24 * 3600
  private let store: any StudentPlanStore
  private let now: @Sendable () -> Date

  public init(
    store: any StudentPlanStore,
    calendar _: Calendar? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.store = store
    self.now = now
  }

  public func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    await store.getPublishedProjection(forStudent: studentID)
  }

  public func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    try await fetchCurrentPlan(studentID: studentID)
  }

  public func fetchDay(studentID: UUID, dayID: UUID) async throws -> StudentPlanDay? {
    try await fetchCurrentPlan(studentID: studentID)?.days.first { $0.id == dayID }
  }

  public func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    guard let plan = try await fetchCurrentPlan(studentID: studentID) else { return [] }
    return StudentPlanSequence.orderedDays(in: plan)
  }

  public func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    try await completeDay(id: id, studentID: studentID, actualCompletionDate: nil)
  }

  public func completeDay(id: UUID, studentID: UUID, actualCompletionDate: String?) async throws
    -> PlanDayCompletion
  {
    guard let plan = try await fetchCurrentPlan(studentID: studentID),
      plan.days.contains(where: { $0.id == id })
    else {
      throw PlanDayCompletionError.planNotActive
    }
    if let day = plan.days.first(where: { $0.id == id }), let completedAt = day.completedAt {
      return PlanDayCompletion(
        id: id,
        dayID: id,
        studentID: studentID,
        source: day.completionSource ?? "manual",
        completedAt: completedAt, actualCompletionDate: day.actualCompletionDate
      )
    }

    let completedAt = now()
    let updated = updatingDay(
      id,
      in: plan,
      completedAt: completedAt,
      source: "manual", actualDate: actualCompletionDate
    )
    await store.savePublishedProjection(updated, forStudent: studentID)
    return PlanDayCompletion(
      id: id,
      dayID: id,
      studentID: studentID,
      source: "manual",
      completedAt: completedAt, actualCompletionDate: actualCompletionDate
    )
  }

  public func undoDayCompletion(id: UUID, studentID: UUID) async throws {
    guard let plan = try await fetchCurrentPlan(studentID: studentID) else {
      throw PlanDayCompletionError.planNotActive
    }
    guard let target = plan.days.first(where: { $0.id == id }),
      let completedAt = target.completedAt
    else {
      // Mirrors backend NO_COMPLETION_TO_UNDO idempotent convergence.
      return
    }
    let latest = plan.days.compactMap { day -> (StudentPlanDay, Date)? in
      day.completedAt.map { (day, $0) }
    }
    .max { lhs, rhs in
      if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
      return lhs.0.id.uuidString < rhs.0.id.uuidString
    }
    guard latest?.0.id == id else {
      throw PlanDayCompletionError.notLatestCompletion
    }
    guard now().timeIntervalSince(completedAt) < Self.completionUndoWindow else {
      throw PlanDayCompletionError.undoWindowPassed
    }

    let updated = updatingDay(id, in: plan, completedAt: nil, source: nil)
    await store.savePublishedProjection(updated, forStudent: studentID)
  }

  private func updatingDay(
    _ dayID: UUID,
    in plan: StudentPlanView,
    completedAt: Date?,
    source: String?, actualDate: String? = nil
  ) -> StudentPlanView {
    let days = plan.days.map { day in
      guard day.id == dayID else { return day }
      return day.replacingCompletion(
        completedAt: completedAt, source: source, actualDate: actualDate)
    }
    return StudentPlanView(
      cycleID: plan.cycleID,
      handoff: plan.handoff,
      actualCompletionDateEnabled: plan.actualCompletionDateEnabled,
      weekIndex: days.first(where: { $0.completedAt == nil })?.weekNumber
        ?? days.last?.weekNumber
        ?? plan.weekIndex,
      startDate: plan.startDate,
      endDate: plan.endDate,
      planKind: plan.planKind,
      publishedAt: plan.publishedAt,
      totalShiftDays: plan.totalShiftDays,
      latestShiftCreatedAt: plan.latestShiftCreatedAt,
      days: days
    )
  }
}
