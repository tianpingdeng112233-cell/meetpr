import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite("Student empty and failure states")
struct StudentEmptyStateViewTests {
  @Test("empty dashboard metrics render both actionable placeholders")
  func emptyDashboardMetricsRenderBothPlaceholders() throws {
    let inspected = try DashboardProfileMetricsView(
      metrics: DashboardProfileMetrics(bodyWeightText: nil, competition: nil),
      showsCompetitionPlaceholder: true,
      showsBodyWeightPlaceholder: true
    ).inspect()

    #expect(
      try inspected.find(
        text: StudentStrings.localized(.dashboardProfileMetricsView009)
      ).string() == StudentStrings.localized(.dashboardProfileMetricsView009)
    )
    #expect(
      try inspected.find(
        text: StudentStrings.localized(.dashboardProfileMetricsView006)
      ).string() == StudentStrings.localized(.dashboardProfileMetricsView006)
    )
  }

  @Test("dashboard restores the structured loading skeleton")
  func dashboardRestoresStructuredLoadingSkeleton() throws {
    let inspected = try DashboardTodayLoadingSkeleton().inspect()

    _ = try inspected.find(viewWithAccessibilityIdentifier: "dashboard.today.loading")
  }

  @Test("rest day cursor restores the header badge")
  func restDayCursorRestoresHeaderBadge() throws {
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [])
    let inspected = try dashboardScreen(cycleDays: [day], days: [day]).inspect()

    #expect(
      try inspected.find(text: StudentStrings.localized(.dashboardTodayScreen006)).string()
        == StudentStrings.localized(.dashboardTodayScreen006)
    )
  }

  @Test("planning state retains the profile metrics row")
  func planningStateRetainsProfileMetricsRow() throws {
    let inspected = try dashboardScreen(
      metricsState: .loaded(DashboardProfileMetrics(bodyWeightText: nil, competition: nil))
    ).inspect()

    #expect(
      try inspected.find(text: StudentStrings.localized(.dashboardTodayScreen005)).string()
        == StudentStrings.localized(.dashboardTodayScreen005)
    )
    #expect(
      try inspected.find(
        text: StudentStrings.localized(.dashboardProfileMetricsView009)
      ).string() == StudentStrings.localized(.dashboardProfileMetricsView009)
    )
    #expect(
      try inspected.find(
        text: StudentStrings.localized(.dashboardProfileMetricsView006)
      ).string() == StudentStrings.localized(.dashboardProfileMetricsView006)
    )
  }

  @Test("profile metrics failures stay visible instead of disappearing")
  func profileMetricsFailuresStayVisible() throws {
    let inspected = try dashboardScreen(metricsState: .error("metrics offline")).inspect()

    #expect(try inspected.find(text: "metrics offline").string() == "metrics offline")
    #expect(
      try inspected.find(text: StudentStrings.localized(.dashboardTodayScreen009)).string()
        == StudentStrings.localized(.dashboardTodayScreen009)
    )
  }

  @Test("loaded empty feedback renders guidance only after loading finishes")
  func loadedEmptyFeedbackRendersGuidance() async throws {
    let viewModel = FeedbackInboxViewModel(repository: InMemoryStudentFeedbackRepository())
    await viewModel.load(studentID: UUID())

    let inspected = try DashboardFeedbackCard(
      items: viewModel.items,
      pending: nil,
      coachName: "Coach",
      viewModel: viewModel,
      isExpanded: .constant(false)
    ).inspect()

    #expect(viewModel.isLoadedEmpty)
    #expect(
      try inspected.find(text: StudentStrings.localized(.dashboardFeedbackCard007)).string()
        == StudentStrings.localized(.dashboardFeedbackCard007)
    )
  }

  @Test("week error and interrupted idle resolve to retry states")
  func weekErrorAndInterruptedIdleResolveToRetryStates() {
    #expect(DashboardWeekContentState.resolve(.idle, hasAttemptedLoad: false) == .initial)
    #expect(
      DashboardWeekContentState.resolve(.idle, hasAttemptedLoad: true)
        == .failed(StudentStrings.localized(.dashboardTodayScreen004))
    )
    #expect(
      DashboardWeekContentState.resolve(.error("network"), hasAttemptedLoad: true)
        == .failed("network")
    )
  }

  @Test("week errors do not render the planning empty state")
  func weekErrorsDoNotRenderPlanningEmptyState() throws {
    let inspected = try dashboardScreen(weekContentState: .failed("week offline")).inspect()

    #expect(try inspected.find(text: "week offline").string() == "week offline")
  }

  @Test("account actions remain reachable in profile fallback states")
  func accountActionsRemainReachableInProfileFallbackStates() async throws {
    let emptyRepository = ScriptedOnboardingRepository()
    let emptyViewModel = MyProfileViewModel(studentId: UUID(), repo: emptyRepository)
    await emptyViewModel.reload()

    let failedRepository = ScriptedOnboardingRepository()
    failedRepository.fetchError = EmptyStateViewTestError.failed
    let failedViewModel = MyProfileViewModel(studentId: UUID(), repo: failedRepository)
    await failedViewModel.reload()

    #expect(emptyViewModel.state == .empty)
    #expect(failedViewModel.state == .failed)

    let inspected = try MyProfileFallbackRows(
      studentID: UUID(),
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
      account: InMemoryAccountRepository(),
      logs: InMemoryStudentTrainingLogRepository(),
      restTimerSettings: EmptyStateRestTimerSettingsStore(),
      trainingReminderServices: TrainingReminderServices(
        store: TrainingReminderUserDefaultsStore(
          defaults: try #require(
            UserDefaults(suiteName: "StudentEmptyStateViewTests.\(UUID().uuidString)"))
        ),
        center: FakeTrainingReminderNotificationCenter()
      ),
      onLogout: nil
    ).inspect()

    _ = try inspected.find(viewWithAccessibilityIdentifier: "account.changePassword")
    _ = try inspected.find(viewWithAccessibilityIdentifier: "account.export")
  }

  @Test("volume chart exposes its own insufficient-data state")
  func volumeChartExposesInsufficientDataState() throws {
    let inspected = try VolumeIntensityChart(buckets: [], isUnlocked: false).inspect()

    #expect(
      try inspected.find(text: StudentStrings.localized(.growthEmptyStates001)).string()
        == StudentStrings.localized(.growthEmptyStates001)
    )
  }

  @Test("e1RM failure stays distinct from true empty history")
  func e1RMFailureStaysDistinctFromTrueEmptyHistory() throws {
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [])
    let inspected = try dashboardScreen(
      cycleDays: [day],
      days: [day],
      trendState: .error("e1RM offline")
    ).inspect()

    #expect(try inspected.find(text: "e1RM offline").string() == "e1RM offline")
    #expect(
      try inspected.find(text: StudentStrings.localized(.dashboardTodayScreen009)).string()
        == StudentStrings.localized(.dashboardTodayScreen009)
    )
  }
}

@MainActor
private func dashboardScreen(
  cycleDays: [StudentPlanDay] = [],
  days: [StudentPlanDay] = [],
  trendState: DashboardE1RMTrendViewModel.State = .loaded(
    DashboardE1RMTrendPresentation(rows: [], headline: nil)
  ),
  metricsState: DashboardProfileMetricsViewModel.State = .loaded(
    DashboardProfileMetrics(bodyWeightText: "80 kg", competition: nil)
  ),
  weekContentState: DashboardWeekContentState = .loaded
) -> DashboardTodayScreen {
  DashboardTodayScreen(
    model: DashboardTodayScreenModel(
      weekIndex: 1,
      planStartDate: nil,
      planEndDate: nil,
      days: days,
      cycleDays: cycleDays,
      logs: [],
      feedbackItems: [],
      isFeedbackLoaded: true,
      trendState: trendState,
      metricsState: metricsState,
      coachName: "Coach",
      newPRCount: 0,
      showsNotifications: false,
      notificationUnreadCount: 0,
      weekContentState: weekContentState,
      now: Date()
    ),
    feedbackViewModel: nil,
    isFeedbackExpanded: .constant(false),
    onOpenNotifications: {},
    onStartWorkout: {},
    isUpdatingCompletion: false,
    onUndoCompletion: { _ in },
    onMessageCoach: {},
    onRetryWeek: {},
    onRetryMetrics: {},
    onRetryTrend: {}
  )
}

private enum EmptyStateViewTestError: Error {
  case failed
}

private struct EmptyStateRestTimerSettingsStore: StudentRestTimerSettingsStoring {
  func preference(for studentID: UUID) -> StudentRestTimerPreference {
    .automatic
  }

  func setPreference(_ preference: StudentRestTimerPreference, for studentID: UUID) {}

  func hasAcknowledgedExplanation(for studentID: UUID) -> Bool {
    false
  }

  func markExplanationAcknowledged(for studentID: UUID) {}
}
