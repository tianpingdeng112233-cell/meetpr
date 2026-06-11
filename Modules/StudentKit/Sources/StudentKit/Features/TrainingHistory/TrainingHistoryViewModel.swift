import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class TrainingHistoryViewModel {
  public enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(weeks: [HistoryWeek], logs: [StudentSetLog])
    case error(String)
  }

  public struct HistoryWeek: Equatable, Sendable, Identifiable {
    public let id: Int
    public let days: [StudentPlanDay]

    public init(id: Int, days: [StudentPlanDay]) {
      self.id = id
      self.days = days
    }
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
      let days = try await plans.fetchCycleDays(studentID: studentID)
      let weeks = stride(from: 0, to: days.count, by: 7).map { start in
        HistoryWeek(id: (start / 7) + 1, days: Array(days[start..<min(start + 7, days.count)]))
      }
      let fetchedLogs: [StudentSetLog]
      if let dateRange = Self.dateRange(for: days) {
        fetchedLogs = try await logs.fetchLogs(studentID: studentID, in: dateRange)
      } else {
        fetchedLogs = []
      }
      state = .loaded(weeks: weeks, logs: fetchedLogs)
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
