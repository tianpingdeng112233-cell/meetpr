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
  private let now: @Sendable () -> Date

  public init(
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.logs = logs
    self.now = now
  }

  public func load(studentID: UUID) async {
    let isInitialLoad = state == .idle
    if isInitialLoad { state = .loading }
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      let days = try await plans.fetchCycleDays(studentID: studentID)
      let weeks = Self.groupByWeek(days, startDate: plan?.startDate)
      let fetchedLogs = try await logs.fetchLogs(
        studentID: studentID,
        in: Self.allHistoryStart...now()
      )
      state = .loaded(weeks: weeks, logs: fetchedLogs)
    } catch {
      if error.isTaskCancellation {
        if isInitialLoad { state = .idle }
        return
      }
      if case .loaded = state { return }
      state = .error(error.localizedDescription)
    }
  }

  /// Groups cycle days into plan weeks by date offset from the plan start.
  /// `fetchCycleDays` returns the whole cycle and days are training days (not a
  /// fixed 7/week), so index chunking would mis-group; bucket by elapsed weeks
  /// from the start date instead. No start date → a single fallback week.
  static func groupByWeek(_ days: [StudentPlanDay], startDate: Date?) -> [HistoryWeek] {
    guard let startDate else {
      return days.isEmpty ? [] : [HistoryWeek(id: 1, days: days)]
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let base = calendar.startOfDay(for: startDate)
    let grouped = Dictionary(grouping: days) { day -> Int in
      let dayStart = calendar.startOfDay(for: day.scheduledDate)
      let elapsed = calendar.dateComponents([.day], from: base, to: dayStart).day ?? 0
      return max(0, elapsed) / 7 + 1
    }
    return grouped.keys.sorted().map { week in
      HistoryWeek(id: week, days: (grouped[week] ?? []).sorted { $0.date < $1.date })
    }
  }

  private static let allHistoryStart = Date(timeIntervalSince1970: 946_684_800)
}
