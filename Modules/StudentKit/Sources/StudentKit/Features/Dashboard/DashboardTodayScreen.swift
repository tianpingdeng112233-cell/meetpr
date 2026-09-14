import CoreModels
import DesignSystem
import SwiftUI

enum DashboardWeekContentState: Equatable, Sendable {
  case initial
  case loading
  case loaded
  case failed(String)

  static func resolve(
    _ state: WeekOverviewViewModel.State,
    hasAttemptedLoad: Bool
  ) -> Self {
    switch state {
    case .idle:
      return hasAttemptedLoad
        ? .failed(StudentStrings.localized(.dashboardTodayScreen004))
        : .initial
    case .loading:
      return .loading
    case .loaded:
      return .loaded
    case .error(let message):
      return .failed(message)
    }
  }
}

struct DashboardTodayScreenModel {
  let weekIndex: Int?
  let planStartDate: Date?
  let planEndDate: Date?
  let days: [StudentPlanDay]
  let cycleDays: [StudentPlanDay]
  let logs: [StudentSetLog]
  let feedbackItems: [CoachFeedback]
  let isFeedbackLoaded: Bool
  let trendState: DashboardE1RMTrendViewModel.State
  let metricsState: DashboardProfileMetricsViewModel.State
  let coachName: String
  let newPRCount: Int
  let showsNotifications: Bool
  let notificationUnreadCount: Int
  let weekContentState: DashboardWeekContentState
  let now: Date
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardTodayScreen: View {
  let model: DashboardTodayScreenModel
  let feedbackViewModel: FeedbackInboxViewModel?
  @Binding var isFeedbackExpanded: Bool
  let onOpenNotifications: () -> Void
  let onStartWorkout: () -> Void
  let isUpdatingCompletion: Bool
  let onUndoCompletion: (UUID) -> Void
  let onMessageCoach: () -> Void
  let onRetryWeek: () -> Void
  let onRetryMetrics: () -> Void
  let onRetryTrend: () -> Void

  private var sequence: StudentPlanSequence {
    StudentPlanSequence(days: model.cycleDays)
  }

  private var cursorDay: StudentPlanDay? {
    sequence.cursorDay
  }

  private var completedToday: StudentPlanDay? {
    DashboardTodayPresentation.completedToday(in: model.cycleDays, now: model.now)
  }

  private var displayDay: StudentPlanDay? {
    completedToday ?? cursorDay ?? sequence.orderedDays.last
  }

  private var selectedTrendRows: [DashboardE1RMTrendRow] {
    guard let displayDay, case .loaded(let presentation) = model.trendState else { return [] }
    let families = MainLiftExerciseFamilyResolver.families(in: displayDay)
    return families.compactMap { family in presentation.rows.first { $0.family == family } }
  }

  private var statusBadge: String? {
    guard model.weekContentState == .loaded else { return nil }
    if sequence.orderedDays.isEmpty {
      return StudentStrings.localized(.dashboardTodayScreen005)
    }
    if cursorDay?.exercises.isEmpty == true {
      return StudentStrings.localized(.dashboardTodayScreen006)
    }
    return cursorDay == nil ? StudentStrings.localized(.dashboardTodayScreen002) : nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      DashboardHeader(
        weekCode: displayDay.map(DashboardTodayPresentation.code(for:))
          ?? StudentStrings.localized(.dashboardTodayScreen001),
        statusBadge: statusBadge,
        showsNotifications: model.showsNotifications,
        unreadCount: model.notificationUnreadCount,
        progressSegments: DashboardTodayPresentation.progressSegments(days: model.cycleDays),
        onOpenNotifications: onOpenNotifications
      )

      switch model.weekContentState {
      case .initial, .loading:
        DashboardTodayLoadingSkeleton()
      case .failed(let message):
        DashboardInlineFailureCard(message: message, retry: onRetryWeek)
      case .loaded where sequence.orderedDays.isEmpty:
        DashboardPlanWaitingState(
          coachName: model.coachName,
          nextWeekIndex: 1,
          summary: DashboardTodayPresentation.weekSummary(
            days: model.days,
            logs: model.logs,
            newPRCount: model.newPRCount
          ),
          onMessageCoach: onMessageCoach
        )

        profileMetricsContent
      case .loaded:
        DashboardFeedbackCard(
          items: model.feedbackItems,
          pending: pendingFeedback,
          coachName: model.coachName,
          viewModel: feedbackViewModel,
          isExpanded: $isFeedbackExpanded
        )

        let segments = DashboardTodayPresentation.progressSegments(days: model.cycleDays)
        if let weekNumber = displayDay?.weekNumber, !segments.isEmpty {
          DashboardWeekCalendar(weekNumber: weekNumber, cells: segments)
        }

        if completedToday == nil, let cursorDay {
          DashboardSequenceDaySummary(day: cursorDay)
        }

        profileMetricsContent

        trendContent

        action
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 6)
    .padding(.bottom, 28)
  }

  @ViewBuilder
  private var profileMetricsContent: some View {
    switch model.metricsState {
    case .idle, .loading:
      DashboardProfileMetricsLoadingSkeleton()
    case .loaded(let metrics):
      DashboardProfileMetricsView(
        metrics: metrics,
        showsCompetitionPlaceholder: metrics.competition == nil,
        showsBodyWeightPlaceholder: metrics.bodyWeightText == nil
      )
    case .error(let message):
      DashboardInlineFailureCard(message: message, retry: onRetryMetrics)
    }
  }

  @ViewBuilder
  private var trendContent: some View {
    switch model.trendState {
    case .idle, .loading:
      DashboardE1RMLoadingSkeleton()
    case .error(let message):
      DashboardInlineFailureCard(message: message, retry: onRetryTrend)
    case .loaded where !selectedTrendRows.isEmpty:
      Text(StudentStrings.localized(.dashboardTodayScreen003))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textSecondary)
      DashboardE1RMRail(rows: selectedTrendRows)
    case .loaded:
      EmptyView()
    }
  }

  @ViewBuilder
  private var action: some View {
    if cursorDay == nil {
      DashboardCycleCompletedAction(days: model.cycleDays)
    } else if let completedToday {
      DashboardCompletedAction(
        completedDay: completedToday,
        nextDay: cursorDay,
        canUndo: true,
        isUpdating: isUpdatingCompletion,
        onUndo: { onUndoCompletion(completedToday.id) },
        onContinue: onStartWorkout
      )
    }
  }

  private var pendingFeedback: DashboardPendingFeedbackPresentation? {
    guard model.isFeedbackLoaded else { return nil }
    return DashboardTodayPresentation.pendingFeedback(
      for: displayDay,
      logs: model.logs,
      feedbackItems: model.feedbackItems,
      now: model.now,
      selectedCalendar: .current
    )
  }

}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardTodayLoadingSkeleton: View {
  var body: some View {
    VStack(spacing: 12) {
      skeleton(height: 112, radius: 12)
      HStack(spacing: 6) {
        ForEach(0..<7, id: \.self) { _ in
          skeleton(height: 44, radius: 12)
        }
      }
      DashboardProfileMetricsLoadingSkeleton()
      skeleton(height: 128, radius: 16)
    }
    .accessibilityLabel(StudentStrings.localized(.dashboardTodayScreen007))
    .accessibilityIdentifier("dashboard.today.loading")
  }

  private func skeleton(height: CGFloat, radius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: radius)
      .fill(Color.MeetPR.textGhost.opacity(0.34))
      .frame(maxWidth: .infinity)
      .frame(height: height)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardProfileMetricsLoadingSkeleton: View {
  var body: some View {
    HStack(spacing: 11) {
      skeleton
      skeleton
    }
    .accessibilityHidden(true)
  }

  private var skeleton: some View {
    RoundedRectangle(cornerRadius: 16)
      .fill(Color.MeetPR.textGhost.opacity(0.34))
      .frame(maxWidth: .infinity)
      .frame(height: 72)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardE1RMLoadingSkeleton: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 16)
      .fill(Color.MeetPR.textGhost.opacity(0.34))
      .frame(maxWidth: .infinity)
      .frame(height: 128)
      .accessibilityHidden(true)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardInlineFailureCard: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Label(
        StudentStrings.localized(.dashboardTodayScreen008),
        systemImage: "exclamationmark.triangle"
      )
      .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
      .foregroundStyle(Color.MeetPR.dangerMuted)
      Text(message)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Button(StudentStrings.localized(.dashboardTodayScreen009), action: retry)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}
