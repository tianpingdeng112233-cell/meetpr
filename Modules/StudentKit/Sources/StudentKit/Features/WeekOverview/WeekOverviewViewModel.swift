import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class WeekOverviewViewModel {
  public enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(days: [StudentPlanDay], logs: [StudentSetLog], weekIndex: Int)
    case error(String)
  }

  public private(set) var state: State = .idle
  public private(set) var planStartDate: Date?
  public private(set) var plan: StudentPlanView?
  public private(set) var cycleDays: [StudentPlanDay] = []

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository

  public init(plans: any StudentPlanRepository, logs: any StudentTrainingLogRepository) {
    self.plans = plans
    self.logs = logs
  }

  public func load(studentID: UUID, serverAuthoritative: Bool = true) async {
    let isInitialLoad = state == .idle
    if isInitialLoad { state = .loading }
    do {
      let plan = try await currentPlan(
        studentID: studentID,
        serverAuthoritative: serverAuthoritative
      )
      self.plan = plan
      planStartDate = plan?.startDate
      let weekIndex =
        plan.flatMap { StudentPlanSequence.cursorDay(in: $0)?.weekNumber }
        ?? plan?.days.map(\.weekNumber).max()
        ?? 1
      // The current-plan projection already contains the whole cycle. Calling
      // fetchCycleDays would resolve the same projection a second time.
      let allDays = plan.map(StudentPlanSequence.orderedDays(in:)) ?? []
      cycleDays = allDays
      let days = Self.currentWeekDays(
        from: allDays, weekIndex: weekIndex)
      let fetchedLogs: [StudentSetLog]
      if let dateRange = Self.dateRange(for: allDays) {
        fetchedLogs = try await logs.fetchLogs(studentID: studentID, in: dateRange)
      } else {
        fetchedLogs = []
      }
      state = .loaded(days: days, logs: fetchedLogs, weekIndex: weekIndex)
    } catch {
      if error.isTaskCancellation {
        if isInitialLoad { state = .idle }
        return
      }
      if case .loaded = state { return }
      state = .error(error.localizedDescription)
    }
  }

  /// Applies a completion mutation projection already fetched by another
  /// student surface. Existing plan-scoped logs stay valid, so this path does
  /// not issue a second sequence-tree request.
  func applyPlanProjection(_ plan: StudentPlanView, studentID: UUID) async {
    let existingLogs: [StudentSetLog]
    if case .loaded(_, let logs, _) = state {
      existingLogs = logs
    } else if let dateRange = Self.dateRange(for: plan.days) {
      if state == .idle { state = .loading }
      existingLogs = (try? await logs.fetchLogs(studentID: studentID, in: dateRange)) ?? []
    } else {
      existingLogs = []
    }
    apply(plan: plan, logs: existingLogs)
  }

  private func currentPlan(
    studentID: UUID,
    serverAuthoritative: Bool
  ) async throws -> StudentPlanView? {
    guard serverAuthoritative else {
      return try await plans.fetchCurrentPlan(studentID: studentID)
    }
    do {
      return try await plans.refreshCurrentPlan(studentID: studentID)
    } catch {
      // Full refreshes prefer the server so a newly published plan wins in one
      // pass. The existing cache remains the offline fallback.
      return try await plans.fetchCurrentPlan(studentID: studentID)
    }
  }

  func refreshLogs(studentID: UUID) async {
    guard case .loaded(let days, _, let weekIndex) = state else { return }
    do {
      let fetchedLogs: [StudentSetLog]
      if let dateRange = Self.dateRange(for: cycleDays) {
        fetchedLogs = try await logs.fetchLogs(studentID: studentID, in: dateRange)
      } else {
        fetchedLogs = []
      }
      state = .loaded(days: days, logs: fetchedLogs, weekIndex: weekIndex)
    } catch {
      if error.isTaskCancellation { return }
      // A volatile refresh must never throw away the week already on screen.
    }
  }

  private static func currentWeekDays(
    from days: [StudentPlanDay], weekIndex: Int
  ) -> [StudentPlanDay] {
    days.filter { $0.weekNumber == weekIndex }
  }

  private func apply(plan: StudentPlanView, logs: [StudentSetLog]) {
    self.plan = plan
    planStartDate = plan.startDate
    let weekIndex =
      StudentPlanSequence.cursorDay(in: plan)?.weekNumber
      ?? plan.days.map(\.weekNumber).max()
      ?? 1
    let allDays = StudentPlanSequence.orderedDays(in: plan)
    cycleDays = allDays
    state = .loaded(
      days: Self.currentWeekDays(from: allDays, weekIndex: weekIndex),
      logs: logs,
      weekIndex: weekIndex
    )
  }

  private static func dateRange(for days: [StudentPlanDay]) -> ClosedRange<Date>? {
    guard let first = days.map(\.scheduledDate).min(), let last = days.map(\.scheduledDate).max()
    else {
      return nil
    }
    // spec 071: one plan-scoped request for the whole cycle, padded one day
    // around coach-authored recommendation dates.
    return first.addingTimeInterval(-86_400)...last.addingTimeInterval(86_400)
  }
}
