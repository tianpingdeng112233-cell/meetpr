import CoreModels
import DesignSystem
import SwiftUI

struct DashboardTodayScreenModel {
  let weekIndex: Int?
  let planStartDate: Date?
  let planEndDate: Date?
  let days: [StudentPlanDay]
  let cycleDays: [StudentPlanDay]
  let logs: [StudentSetLog]
  let feedbackItems: [CoachFeedback]
  let isFeedbackLoaded: Bool
  let trendRows: [DashboardE1RMTrendRow]
  let metrics: DashboardProfileMetrics?
  let coachName: String
  let newPRCount: Int
  let showsNotifications: Bool
  let notificationUnreadCount: Int
  let isLoading: Bool
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
    guard let displayDay else { return [] }
    let families = MainLiftExerciseFamilyResolver.families(in: displayDay)
    return families.compactMap { family in model.trendRows.first { $0.family == family } }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      DashboardHeader(
        weekCode: displayDay.map(DashboardTodayPresentation.code(for:)) ?? "今日",
        selectedDate: displayDay?.scheduledDate ?? model.now,
        statusBadge: cursorDay == nil && !sequence.orderedDays.isEmpty ? "已完成" : nil,
        showsNotifications: model.showsNotifications,
        unreadCount: model.notificationUnreadCount,
        progressSegments: DashboardTodayPresentation.progressSegments(days: model.cycleDays),
        onOpenNotifications: onOpenNotifications
      )
      .meetPRRiseIn(delay: riseDelay(index: 0))

      if model.isLoading {
        ProgressView().frame(maxWidth: .infinity, minHeight: 220)
      } else if sequence.orderedDays.isEmpty {
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
      } else {
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

        if let metrics = model.metrics {
          DashboardProfileMetricsView(metrics: metrics)
        }

        if !selectedTrendRows.isEmpty {
          Text("本节 · E1RM 曲线")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textSecondary)
          DashboardE1RMRail(rows: selectedTrendRows)
        }

        action
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 6)
    .padding(.bottom, 28)
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

  private func riseDelay(index: Int) -> TimeInterval {
    MeetPRMotion.riseInitialDelay + (Double(index) * MeetPRMotion.riseStagger)
  }
}
