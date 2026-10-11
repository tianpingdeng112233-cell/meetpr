import Foundation

struct ProgressMenuValues: Equatable, Sendable {
  let e1rm: String
  let history: String
  let feedback: String
  let feedbackEmphasized: Bool
  let intensity: String

  static func make(
    totalKg: Double?, stats: GrowthHistoryStats, feedbackCount: Int, unreadCount: Int,
    buckets: [WeeklyProgressMetric], locale: Locale = .current
  ) -> Self {
    let total =
      totalKg.map {
        StudentStrings.replacing(
          .progressTotalValue,
          values: [$0.formatted(.number.precision(.fractionLength(1)).locale(locale))],
          locale: locale)
      } ?? "—"
    let history =
      stats.trainingSessionCount > 0
      ? StudentStrings.progressCount(stats.trainingSessionCount, unread: false, locale: locale)
      : "—"
    let feedback =
      unreadCount > 0
      ? StudentStrings.progressCount(unreadCount, unread: true, locale: locale)
      : feedbackCount > 0 ? feedbackCount.formatted(.number.grouping(.never).locale(locale)) : "—"
    let intensity: String
    if stats.unlocksTrends, let rpe = buckets.last?.avgRPE {
      intensity = StudentStrings.replacing(
        .progressRpe, values: [rpe.formatted(.number.precision(.fractionLength(1)).locale(locale))],
        locale: locale)
    } else {
      intensity = "—"
    }
    return Self(
      e1rm: total, history: history, feedback: feedback, feedbackEmphasized: unreadCount > 0,
      intensity: intensity)
  }
}
