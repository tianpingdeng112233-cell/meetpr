import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func progressMenuValuesCoverLoadedEmptyAndUnreadStates() {
  let english = Locale(identifier: "en_US")
  let chinese = Locale(identifier: "zh_Hans")
  let stats = GrowthHistoryStats(trainingSessionCount: 4, trainingWeekCount: 2, totalVolumeKg: 1000)
  let buckets = [WeeklyProgressMetric(weekStart: Date(), volumeKg: 1000, avgRPE: 7.75)]
  let values = ProgressMenuValues.make(
    totalKg: 484.6, stats: stats, feedbackCount: 3, unreadCount: 2,
    buckets: buckets, locale: english)
  #expect(values.e1rm == "Total 484.6 kg")
  #expect(values.history == "4 sessions")
  #expect(values.feedback == "2 new")
  #expect(values.feedbackEmphasized)
  #expect(values.intensity == "RPE 7.8")
  let empty = ProgressMenuValues.make(
    totalKg: nil,
    stats: GrowthHistoryStats(trainingSessionCount: 0, trainingWeekCount: 0, totalVolumeKg: 0),
    feedbackCount: 0, unreadCount: 0, buckets: buckets, locale: english)
  #expect([empty.e1rm, empty.history, empty.feedback, empty.intensity] == ["—", "—", "—", "—"])
  let single = ProgressMenuValues.make(
    totalKg: nil,
    stats: GrowthHistoryStats(trainingSessionCount: 1, trainingWeekCount: 1, totalVolumeKg: 100),
    feedbackCount: 3, unreadCount: 0, buckets: [], locale: english)
  #expect(single.history == "1 session")
  #expect(single.feedback == "3")
  #expect(!single.feedbackEmphasized)
  #expect(single.intensity == "—")
  let noRPE = ProgressMenuValues.make(
    totalKg: nil, stats: stats, feedbackCount: 0, unreadCount: 0,
    buckets: buckets + [WeeklyProgressMetric(weekStart: Date(), volumeKg: 10, avgRPE: nil)],
    locale: english)
  #expect(noRPE.intensity == "—")
  let localized = ProgressMenuValues.make(
    totalKg: 484.6, stats: stats, feedbackCount: 3, unreadCount: 1,
    buckets: buckets, locale: chinese)
  #expect(localized.e1rm == "合计 484.6 kg")
  #expect(localized.history == "4 次训练")
  #expect(localized.feedback == "1 条未读")
}
