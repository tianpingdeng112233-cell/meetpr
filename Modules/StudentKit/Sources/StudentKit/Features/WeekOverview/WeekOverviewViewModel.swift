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

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository

  public init(plans: any StudentPlanRepository, logs: any StudentTrainingLogRepository) {
    self.plans = plans
    self.logs = logs
  }

  public func load(studentID: UUID) async {
    state = .loading
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      let days = try await plans.fetchCycleDays(studentID: studentID)
      let fetchedLogs: [StudentSetLog]
      if let dateRange = Self.dateRange(for: days) {
        fetchedLogs = try await logs.fetchLogs(studentID: studentID, in: dateRange)
      } else {
        fetchedLogs = []
      }
      state = .loaded(days: days, logs: fetchedLogs, weekIndex: plan?.weekIndex ?? 1)
    } catch {
      state = .error(error.localizedDescription)
    }
  }

  private static func dateRange(for days: [StudentPlanDay]) -> ClosedRange<Date>? {
    guard let first = days.map(\.date).min(), let last = days.map(\.date).max() else {
      return nil
    }
    return first...last.addingTimeInterval(86_400 - 1)
  }
}
