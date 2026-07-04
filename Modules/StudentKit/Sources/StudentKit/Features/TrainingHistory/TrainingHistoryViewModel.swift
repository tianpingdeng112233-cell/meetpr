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

  /// One solo training day (spec 047 §2): 日即会话, summarized for the
  /// month-grouped history list.
  public struct HistoryDaySession: Equatable, Sendable, Identifiable {
    public let date: Date
    public let dayKey: String
    public let exerciseNames: [String]
    public let setCount: Int
    public let bestE1RMKg: Double?
    public var id: String { dayKey }
  }

  /// Calendar-month section replacing plan weeks for solo students.
  public struct SoloHistoryMonth: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let days: [HistoryDaySession]
  }

  public private(set) var state: State = .idle
  /// Day (YYYY-MM-DD, local calendar) → that day's session review (spec 051
  /// §1 回显). Decoration on the day cards: empty when no repository is wired.
  public private(set) var reviewsByDay: [String: SessionReview] = [:]
  /// Month-grouped solo sessions (spec 047 §2); empty in coached mode.
  public private(set) var soloMonths: [SoloHistoryMonth] = []

  /// Rolling fetch window for planless history (>180 天分页记 F-030 族).
  static let soloWindowDays = 180

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let reviews: (any SessionReviewRepository)?
  private let e1rm: (any E1RMRepository)?
  private let mode: TrainingMode
  private let catalogNames: [UUID: String]
  private let catalogBuckets: [LiftFamily: Set<UUID>]
  private let now: @Sendable () -> Date

  public init(
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    reviews: (any SessionReviewRepository)? = nil,
    e1rm: (any E1RMRepository)? = nil,
    mode: TrainingMode = .coached,
    catalog: [Exercise] = [],
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.logs = logs
    self.reviews = reviews
    self.e1rm = e1rm
    self.mode = mode
    self.catalogNames = Dictionary(
      catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    self.catalogBuckets = MainLiftExerciseFamilyResolver.exerciseIDsByFamily(catalog: catalog)
    self.now = now
  }

  public func load(studentID: UUID) async {
    if mode == .selfTrain {
      await loadSolo(studentID: studentID)
      return
    }
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

  /// Planless history (spec 047 §2): scope=all over a rolling window, grouped
  /// by calendar month — 日即会话, no plan weeks to group by.
  private func loadSolo(studentID: UUID) async {
    state = .loading
    do {
      let end = now()
      let start = end.addingTimeInterval(-Double(Self.soloWindowDays) * 86_400)
      let fetched = try await logs.fetchLogs(studentID: studentID, in: start...end, scope: .all)
      reviewsByDay = await fetchReviewIndex(studentID: studentID, days: [], logs: fetched)
      soloMonths = Self.soloMonths(
        logs: fetched,
        names: catalogNames,
        bestByDay: await soloBestByDay(studentID: studentID),
        calendar: .current
      )
      state = .loaded(weeks: [], logs: fetched)
    } catch {
      if error.isTaskCancellation {
        state = .idle
        return
      }
      state = .error(error.localizedDescription)
    }
  }

  /// Day (YYYY-MM-DD) → best eligibility-gated raw e1RM across comp lifts.
  /// Decoration on the day cards — a failed fetch just hides the number.
  private func soloBestByDay(studentID: UUID) async -> [String: Double] {
    guard let e1rm else { return [:] }
    var best: [String: Double] = [:]
    for (family, ids) in catalogBuckets {
      guard
        let histories = try? await e1rm.fetchHistory(
          studentId: studentID, exerciseIds: Array(ids))
      else { continue }
      let eligible = E1RMSeries.eligibleRaw(
        points: histories.values.flatMap { $0 }, family: family)
      for point in eligible {
        let key = SoloSessionViewModel.dayString(point.computedAt, calendar: .current)
        best[key] = max(best[key] ?? 0, point.e1RMKg)
      }
    }
    return best
  }

  static func soloMonths(
    logs: [StudentSetLog],
    names: [UUID: String],
    bestByDay: [String: Double],
    calendar: Calendar
  ) -> [SoloHistoryMonth] {
    let completed = logs.filter(\.completed)
    let byDay = Dictionary(grouping: completed) { calendar.startOfDay(for: $0.loggedAt) }
    let sessions = byDay.map { day, dayLogs -> HistoryDaySession in
      var seen: Set<String> = []
      let ordered = dayLogs.sorted { $0.loggedAt < $1.loggedAt }
      let exerciseNames = ordered.compactMap { log -> String? in
        let name = log.exerciseID.flatMap { names[$0] } ?? "动作"
        return seen.insert(name).inserted ? name : nil
      }
      let key = SoloSessionViewModel.dayString(day, calendar: calendar)
      return HistoryDaySession(
        date: day,
        dayKey: key,
        exerciseNames: exerciseNames,
        setCount: dayLogs.count,
        bestE1RMKg: bestByDay[key]
      )
    }
    .sorted { $0.date > $1.date }

    let byMonth = Dictionary(grouping: sessions) { session in
      monthKey(for: session.date, calendar: calendar)
    }
    return byMonth.keys.sorted(by: >).map { key in
      SoloHistoryMonth(id: key, title: monthTitle(for: key), days: byMonth[key] ?? [])
    }
  }

  static func monthKey(for date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month], from: date)
    return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
  }

  static func monthTitle(for key: String) -> String {
    let parts = key.split(separator: "-")
    guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
      return key
    }
    return "\(year) 年 \(month) 月"
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
