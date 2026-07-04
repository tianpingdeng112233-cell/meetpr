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
  /// Day (YYYY-MM-DD, local calendar) → that day's session review (spec 051
  /// §1 回显). Decoration on the day cards: empty when no repository is wired.
  public private(set) var reviewsByDay: [String: SessionReview] = [:]

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let reviews: (any SessionReviewRepository)?

  public init(
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    reviews: (any SessionReviewRepository)? = nil
  ) {
    self.plans = plans
    self.logs = logs
    self.reviews = reviews
  }

  public func load(studentID: UUID) async {
    state = .loading
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      let days = try await plans.fetchCycleDays(studentID: studentID)
      let weeks = Self.groupByWeek(days, startDate: plan?.startDate)
      let fetchedLogs: [StudentSetLog]
      if let dateRange = Self.dateRange(for: days) {
        fetchedLogs = try await logs.fetchLogs(studentID: studentID, in: dateRange)
      } else {
        fetchedLogs = []
      }
      reviewsByDay = await fetchReviewIndex(studentID: studentID, days: days, logs: fetchedLogs)
      state = .loaded(weeks: weeks, logs: fetchedLogs)
    } catch {
      if error.isTaskCancellation {
        state = .idle
        return
      }
      state = .error(error.localizedDescription)
    }
  }

  /// Reviews are decoration on the day cards — a failed fetch hides the line
  /// instead of failing the whole history load.
  private func fetchReviewIndex(
    studentID: UUID, days: [StudentPlanDay], logs: [StudentSetLog]
  ) async -> [String: SessionReview] {
    guard let reviews else { return [:] }
    let dates = days.map(\.date) + logs.map(\.loggedAt)
    guard let first = dates.min(), let last = dates.max() else { return [:] }
    let fetched =
      (try? await reviews.fetchReviews(
        studentID: studentID,
        from: SoloSessionViewModel.dayString(first, calendar: .current),
        to: SoloSessionViewModel.dayString(last, calendar: .current)
      )) ?? []
    return Dictionary(fetched.map { ($0.reviewDate, $0) }) { first, _ in first }
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
      let dayStart = calendar.startOfDay(for: day.date)
      let elapsed = calendar.dateComponents([.day], from: base, to: dayStart).day ?? 0
      return max(0, elapsed) / 7 + 1
    }
    return grouped.keys.sorted().map { week in
      HistoryWeek(id: week, days: (grouped[week] ?? []).sorted { $0.date < $1.date })
    }
  }

  private static func dateRange(for days: [StudentPlanDay]) -> ClosedRange<Date>? {
    guard let first = days.map(\.date).min(), let last = days.map(\.date).max() else {
      return nil
    }
    return first...last.addingTimeInterval(86_400 - 1)
  }
}
