import Foundation

/// Per-week prescribed-vs-completed aggregation for the coach analytics
/// A-group "完成率" view. Pure domain reduction over the full-cycle plan tree
/// (`StudentPlanDay`, each carrying prescribed sets) and the student's set
/// logs.
///
/// Weeks are cycle-aligned (7-day buckets from the earliest planned training
/// day) so they read as 第1周/第2周 regardless of calendar week start.
/// A "training day" is a plan day with ≥1 prescribed exercise; rest days are
/// excluded from the denominator. Completion is attributed through
/// `planExerciseID → plan day` (not by log calendar date), so a set logged a
/// day late still counts toward the day it was prescribed for.
///
/// Completion measures *adherence* (did the prescribed work happen), so it
/// counts `completed` logs and deliberately does NOT apply the RPE<5
/// junk-volume filter — that filter is for effective-volume metrics, not for
/// "did they do it". See
/// `~/Brain/wiki/projects/MeetPR/domain/coach-analytics-v1-scope.md` §1-2.
public enum CompletionHistory {
  public struct Week: Equatable, Sendable, Identifiable {
    /// 0-based index from the first planned training day.
    public let weekIndex: Int
    public let weekStart: Date
    public let plannedTrainingDays: Int
    public let completedTrainingDays: Int
    public let plannedSets: Int
    public let completedSets: Int

    public var id: Int { weekIndex }

    /// Completed ÷ planned training days (0 when nothing planned).
    public var dayCompletionRate: Double {
      plannedTrainingDays > 0
        ? Double(completedTrainingDays) / Double(plannedTrainingDays) : 0
    }

    /// Completed ÷ planned sets (0 when nothing planned). May exceed 1 when the
    /// student logged more than prescribed — left uncapped here; display clamps.
    public var setCompletionRate: Double {
      plannedSets > 0 ? Double(completedSets) / Double(plannedSets) : 0
    }

    public init(
      weekIndex: Int,
      weekStart: Date,
      plannedTrainingDays: Int,
      completedTrainingDays: Int,
      plannedSets: Int,
      completedSets: Int
    ) {
      self.weekIndex = weekIndex
      self.weekStart = weekStart
      self.plannedTrainingDays = plannedTrainingDays
      self.completedTrainingDays = completedTrainingDays
      self.plannedSets = plannedSets
      self.completedSets = completedSets
    }
  }

  /// - Parameters:
  ///   - planDays: full-cycle plan days (e.g. from `StudentPlanRepository.fetchCycleDays`).
  ///   - logs: the student's set logs across the cycle window.
  ///   - calendar: used only for start-of-day / week bucketing.
  /// - Returns: one `Week` per cycle week that has ≥1 planned training day,
  ///   ascending by week index.
  public static func weekly(
    planDays: [StudentPlanDay],
    logs: [StudentSetLog],
    calendar: Calendar = Calendar(identifier: .gregorian)
  ) -> [Week] {
    let trainingDays = planDays.filter { day in
      day.exercises.contains { !$0.prescribedSets.isEmpty }
    }
    guard let cycleStart = trainingDays.map(\.date).min() else { return [] }
    let cycleStartDay = calendar.startOfDay(for: cycleStart)

    func weekIndex(of date: Date) -> Int {
      let day = calendar.startOfDay(for: date)
      let days = calendar.dateComponents([.day], from: cycleStartDay, to: day).day ?? 0
      return max(0, days / 7)
    }

    // planExerciseID → its plan day's id, and day id → week index.
    var dayForExercise: [UUID: UUID] = [:]
    var weekForDay: [UUID: Int] = [:]
    for day in trainingDays {
      let week = weekIndex(of: day.date)
      weekForDay[day.id] = week
      for exercise in day.exercises where !exercise.prescribedSets.isEmpty {
        dayForExercise[exercise.id] = day.id
      }
    }

    // Completed work attributed to weeks via plan-exercise (date-agnostic).
    var completedSetsByWeek: [Int: Int] = [:]
    var completedDaysByWeek: [Int: Set<UUID>] = [:]
    for log in logs where log.completed {
      guard let dayID = dayForExercise[log.planExerciseID],
        let week = weekForDay[dayID]
      else { continue }
      completedSetsByWeek[week, default: 0] += 1
      completedDaysByWeek[week, default: []].insert(dayID)
    }

    // Planned aggregates per week.
    var plannedDaysByWeek: [Int: Set<UUID>] = [:]
    var plannedSetsByWeek: [Int: Int] = [:]
    for day in trainingDays {
      let week = weekIndex(of: day.date)
      plannedDaysByWeek[week, default: []].insert(day.id)
      plannedSetsByWeek[week, default: 0] +=
        day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    }

    return plannedDaysByWeek.keys.sorted().map { week in
      let weekStart =
        calendar.date(byAdding: .day, value: week * 7, to: cycleStartDay) ?? cycleStartDay
      return Week(
        weekIndex: week,
        weekStart: weekStart,
        plannedTrainingDays: plannedDaysByWeek[week]?.count ?? 0,
        completedTrainingDays: completedDaysByWeek[week]?.count ?? 0,
        plannedSets: plannedSetsByWeek[week] ?? 0,
        completedSets: completedSetsByWeek[week] ?? 0
      )
    }
  }
}
