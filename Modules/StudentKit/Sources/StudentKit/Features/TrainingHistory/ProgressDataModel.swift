import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Shares the existing history, growth and feedback repositories across the four destinations.
@Observable
@MainActor
final class ProgressDataModel {
  let history: TrainingHistoryViewModel
  let growth: GrowthCurveViewModel
  let feedback: FeedbackInboxViewModel
  private let studentID: UUID
  private let onboarding: (any OnboardingProfileReading)?
  private var profile: OnboardingProfile?
  private var allSnapshots: [GrowthCurveSnapshot] = []
  private var monthSnapshots: [GrowthCurveSnapshot] = []
  private var quarterSnapshots: [GrowthCurveSnapshot] = []
  private var isLoading = false

  init(
    studentID: UUID, plans: any StudentPlanRepository, logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository, onboarding: (any OnboardingProfileReading)?,
    feedback: FeedbackInboxViewModel?
  ) {
    self.studentID = studentID
    self.onboarding = onboarding
    history = TrainingHistoryViewModel(plans: plans, logs: logs)
    growth = GrowthCurveViewModel(plans: plans, e1rm: e1rm, onboarding: onboarding, logs: logs)
    self.feedback =
      feedback ?? FeedbackInboxViewModel(repository: InMemoryStudentFeedbackRepository())
  }

  var isLoaded: Bool {
    guard case .loaded = history.state, growth.state == .loaded else { return false }
    return allSnapshots.count == 3
  }

  var isFailed: Bool {
    if case .error = history.state { return true }
    if case .error = growth.state { return true }
    if case .error = feedback.state { return true }
    return false
  }

  var logs: [StudentSetLog] {
    guard case .loaded(_, let logs) = history.state else { return [] }
    return logs
  }

  var stats: GrowthHistoryStats { GrowthScreenPresentation.historyStats(logs: logs) }
  var buckets: [WeeklyProgressMetric] { GrowthScreenPresentation.chartBuckets(logs: logs) }
  var comparison: GrowthComparisonPresentation {
    GrowthComparisonPresentation.make(snapshots: allSnapshots, onboarding: profile)
  }

  var menuValues: ProgressMenuValues? {
    guard isLoaded, feedback.hasFinishedLoading, !isFailed else { return nil }
    return ProgressMenuValues.make(
      totalKg: comparison.estimatedTotalKg, stats: stats, feedbackCount: feedback.items.count,
      unreadCount: feedback.unreadCount, buckets: buckets)
  }

  func snapshot(family: LiftFamily, range: GrowthTimeRange) -> GrowthCurveSnapshot {
    let snapshots: [GrowthCurveSnapshot]
    switch range {
    case .all: snapshots = allSnapshots
    case .thirtyDays: snapshots = monthSnapshots
    case .ninetyDays: snapshots = quarterSnapshots
    }
    return snapshots.first { $0.family == family } ?? .empty(family: family)
  }

  func total(range: GrowthTimeRange) -> GrowthTotalPresentation {
    GrowthTotalPresentation.make(snapshots: allSnapshots, range: range)
  }

  func detail(pointID: UUID) -> GrowthE1RMDetail? {
    guard case .loaded(let weeks, let logs) = history.state else { return nil }
    return growth.detail(forPointID: pointID, logs: logs, days: weeks.flatMap(\.days))
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    profile = try? await onboarding?.fetchProfile(studentId: studentID)
    await history.load(studentID: studentID)
    await growth.load(studentID: studentID)
    allSnapshots = snapshots(range: .all)
    monthSnapshots = snapshots(range: .thirtyDays)
    quarterSnapshots = snapshots(range: .ninetyDays)
    await feedback.load(studentID: studentID)
  }

  private func snapshots(range: GrowthTimeRange) -> [GrowthCurveSnapshot] {
    MainLiftExerciseFamilyResolver.dashboardFamilies.map {
      GrowthScreenPresentation.snapshot(from: growth, family: $0, range: range)
    }
  }
}
