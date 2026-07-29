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

  public func load(studentID: UUID) async {
    let isInitialLoad = state == .idle
    if isInitialLoad { state = .loading }
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      self.plan = plan
      planStartDate = plan?.startDate
      let weekIndex = plan?.weekIndex ?? 1
      // The current-plan projection already contains the whole cycle. Calling
      // fetchCycleDays would resolve the same projection a second time.
      let allDays = plan?.days.sorted { $0.date < $1.date } ?? []
      cycleDays = allDays
      let days = Self.currentWeekDays(
        from: allDays, startDate: plan?.startDate, weekIndex: weekIndex)
      let fetchedLogs: [StudentSetLog]
      if let dateRange = Self.dateRange(for: days) {
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

  func refreshLogs(studentID: UUID) async {
    guard case .loaded(let days, _, let weekIndex) = state else { return }
    do {
      let fetchedLogs: [StudentSetLog]
      if let dateRange = Self.dateRange(for: days) {
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

  /// The plan-week window `[startDate + (weekIndex-1)*7, +7)` narrows the full
  /// cycle down to "this week" for the dashboard strip. UTC to match the
  /// projection's date computation.
  private static func currentWeekDays(
    from days: [StudentPlanDay], startDate: Date?, weekIndex: Int
  ) -> [StudentPlanDay] {
    guard let startDate else { return days }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let base = calendar.startOfDay(for: startDate)
    guard
      let weekStart = calendar.date(byAdding: .day, value: (weekIndex - 1) * 7, to: base),
      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
    else { return days }
    return days.filter { $0.date >= weekStart && $0.date < weekEnd }
  }

  private static func dateRange(for days: [StudentPlanDay]) -> ClosedRange<Date>? {
    guard let first = days.map(\.date).min(), let last = days.map(\.date).max() else {
      return nil
    }
    return first...last.addingTimeInterval(86_400 - 1)
  }
}
