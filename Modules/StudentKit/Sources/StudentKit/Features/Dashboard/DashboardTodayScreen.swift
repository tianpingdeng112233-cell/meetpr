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
  let canShiftPlanDays: Bool
  let canUndoPlanShift: Bool
  let isUpdatingDayShift: Bool
  let isLoading: Bool
  let now: Date
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardTodayScreen: View {
  let model: DashboardTodayScreenModel
  let feedbackViewModel: FeedbackInboxViewModel?
  @Binding var selectedDate: Date?
  @Binding var isFeedbackExpanded: Bool
  let onOpenNotifications: () -> Void
  let onStartWorkout: () -> Void
  let onStartWorkoutFrameChange: (CGRect) -> Void
  let isStartWorkoutHidden: Bool
  let onShiftPlan: () -> Void
  let onUndoShift: () -> Void
  let onMessageCoach: () -> Void

  /// The repo's date-identity contract is mixed on purpose: plan days compare
  /// by UTC components, "today"/selection by the device calendar — the same
  /// convention the training tab uses. Pinning UTC here shifts the whole page
  /// a day backwards for UTC+ users before 08:00.
  private var calendar: Calendar {
    .current
  }

  private var effectiveSelectedDate: Date {
    selectedDate ?? model.now
  }

  private var selectedDay: StudentPlanDay? {
    DashboardTodayPresentation.planDay(
      on: effectiveSelectedDate,
      in: model.days,
      selectedCalendar: calendar
    )
  }

  private var selectedFamilies: [LiftFamily] {
    selectedDay.map(MainLiftExerciseFamilyResolver.families(in:)) ?? []
  }

  private var selectedTrendRows: [DashboardE1RMTrendRow] {
    selectedFamilies.compactMap { family in
      model.trendRows.first { $0.family == family }
    }
  }

  private var isSelectedToday: Bool {
    calendar.isDate(effectiveSelectedDate, inSameDayAs: model.now)
  }

  private var isRestDay: Bool {
    selectedDay?.exercises.isEmpty ?? true
  }

  private var weekCode: String {
    if isAwaitingNextPlan {
      return "W\(nextWeekIndex)"
    }
    return DashboardTodayPresentation.weekCode(
      weekIndex: model.weekIndex,
      selectedDate: effectiveSelectedDate,
      days: model.days,
      selectedCalendar: calendar
    )
  }

  private var nextWeekIndex: Int {
    max(1, (model.weekIndex ?? 0) + 1)
  }

  private var isAwaitingNextPlan: Bool {
    isSelectedToday
      && DashboardTodayPresentation.isAwaitingNextPlan(
        planEndDate: model.planEndDate,
        cycleDays: model.cycleDays,
        now: model.now,
        selectedCalendar: calendar
      )
  }

  private var liftSubtitle: String {
    DashboardTodayPresentation.liftSubtitle(selectedFamilies)
  }

  private var canShiftSelectedDay: Bool {
    guard model.canShiftPlanDays,
      isSelectedToday,
      let selectedDay,
      TrainingDayProgress(day: selectedDay, logs: model.logs).state == .notStarted,
      // The shift mutation anchors "today" to UTC (spec 054); hide the entry
      // while device-today and UTC-today resolve to different plan days
      // (00:00–08:00 in UTC+8), or the dialog would describe one session and
      // the server would move another.
      DashboardTodayPresentation.shiftTargetsSelectedDay(selectedDay, now: model.now)
    else {
      return false
    }
    let exerciseIDs = Set(selectedDay.exercises.map(\.id))
    return !model.logs.contains { exerciseIDs.contains($0.planExerciseID) }
  }

  private var actionState: DashboardTodayActionState {
    DashboardTodayPresentation.actionState(
      isSelectedToday: isSelectedToday,
      isRestDay: isRestDay,
      canUndoPlanShift: model.canUndoPlanShift
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      DashboardHeader(
        weekCode: weekCode,
        selectedDate: effectiveSelectedDate,
        statusBadge: isAwaitingNextPlan ? "编排中" : (isRestDay ? "休息日" : nil),
        showsNotifications: model.showsNotifications,
        unreadCount: model.notificationUnreadCount,
        progressSegments: DashboardTodayPresentation.progressSegments(
          days: model.days,
          logs: model.logs,
          today: model.now,
          selectedCalendar: calendar
        ),
        onOpenNotifications: onOpenNotifications
      )
      // motion/04 lines 28-35: 今日页 base=20ms, step=40ms.
      .meetPRRiseIn(delay: riseDelay(index: 0))

      if model.isLoading {
        DashboardTodayLoadingSkeleton()
          .meetPRRiseIn(delay: riseDelay(index: 1))
      } else if isAwaitingNextPlan {
        DashboardPlanWaitingState(
          coachName: model.coachName,
          nextWeekIndex: nextWeekIndex,
          summary: DashboardTodayPresentation.weekSummary(
            days: model.days,
            logs: model.logs,
            newPRCount: model.newPRCount
          ),
          onMessageCoach: onMessageCoach
        )
        .meetPRRiseIn(delay: riseDelay(index: 1))

        if let metrics = model.metrics {
          DashboardProfileMetricsView(
            metrics: metrics,
            showsCompetitionPlaceholder: metrics.competition == nil
          )
          .meetPRRiseIn(delay: riseDelay(index: 2))
        }
      } else {
        DashboardFeedbackCard(
          items: model.feedbackItems,
          pending: pendingFeedback,
          coachName: model.coachName,
          viewModel: feedbackViewModel,
          isExpanded: $isFeedbackExpanded
        )
        .meetPRRiseIn(delay: riseDelay(index: 1))

        DashboardWeekCalendar(
          cells: DashboardTodayPresentation.calendarCells(
            days: model.days,
            logs: model.logs,
            selectedDate: effectiveSelectedDate,
            today: model.now,
            selectedCalendar: calendar
          ),
          onSelect: { selectedDate = $0 }
        )
        .meetPRRiseIn(delay: riseDelay(index: 2))

        if let metrics = model.metrics {
          DashboardProfileMetricsView(metrics: metrics)
            .meetPRRiseIn(delay: riseDelay(index: 3))
        }

        Text("周\(weekdayLetter) · E1RM 曲线")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .padding(.top, -5)
          .meetPRRiseIn(delay: riseDelay(index: trendTitleRiseIndex))

        if isRestDay {
          DashboardRestDayCard(
            isToday: isSelectedToday,
            preview: DashboardTodayPresentation.restDayPreview(
              after: effectiveSelectedDate,
              days: model.cycleDays,
              planStartDate: model.planStartDate,
              fallbackWeekIndex: model.weekIndex,
              selectedCalendar: calendar
            )
          )
          .meetPRRiseIn(delay: riseDelay(index: trendContentRiseIndex))
        } else if !selectedTrendRows.isEmpty {
          DashboardE1RMRail(rows: selectedTrendRows)
            .meetPRRiseIn(delay: riseDelay(index: trendContentRiseIndex))
        }

        switch actionState {
        case .postponed:
          DashboardPostponedState(
            tomorrowLabel: tomorrowLabel,
            isUpdatingShift: model.isUpdatingDayShift,
            onUndo: onUndoShift
          )
          .meetPRRiseIn(delay: riseDelay(index: actionRiseIndex))
        case .primary:
          DashboardPrimaryAction(
            liftSubtitle: liftSubtitle,
            canShift: canShiftSelectedDay,
            isUpdatingShift: model.isUpdatingDayShift,
            onStart: onStartWorkout,
            onStartFrameChange: onStartWorkoutFrameChange,
            isStartHidden: isStartWorkoutHidden,
            onShift: onShiftPlan
          )
          .meetPRRiseIn(delay: riseDelay(index: actionRiseIndex))
        case .hidden:
          EmptyView()
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 6)
    .padding(.bottom, 28)
  }

  private var pendingFeedback: DashboardPendingFeedbackPresentation? {
    guard model.isFeedbackLoaded else { return nil }
    return DashboardTodayPresentation.pendingFeedback(
      for: selectedDay,
      logs: model.logs,
      feedbackItems: model.feedbackItems,
      now: model.now,
      selectedCalendar: calendar
    )
  }

  private var weekdayLetter: String {
    let offset = DashboardTodayPresentation.mondayOffset(
      for: effectiveSelectedDate,
      calendar: calendar
    )
    return DashboardTodayPresentation.weekdayLetter(offset)
  }

  private var trendTitleRiseIndex: Int {
    model.metrics == nil ? 3 : 4
  }

  private var trendContentRiseIndex: Int {
    trendTitleRiseIndex + 1
  }

  private var actionRiseIndex: Int {
    trendContentRiseIndex + 1
  }

  private func riseDelay(index: Int) -> TimeInterval {
    MeetPRMotion.riseInitialDelay + (Double(index) * MeetPRMotion.riseStagger)
  }

  private var tomorrowLabel: String {
    let tomorrow =
      calendar.date(byAdding: .day, value: 1, to: model.now)
      ?? model.now.addingTimeInterval(86_400)
    // "Tomorrow" is a device-calendar concept — format it with the same
    // calendar that computed it, or the month/day and weekday can disagree.
    let monthDay = DashboardTodayPresentation.monthDayText(tomorrow, calendar: calendar)
    let offset = DashboardTodayPresentation.mondayOffset(for: tomorrow, calendar: calendar)
    return "明天 · \(monthDay) 周\(DashboardTodayPresentation.weekdayLetter(offset))"
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardTodayLoadingSkeleton: View {
  var body: some View {
    VStack(spacing: 12) {
      skeleton(height: 112, radius: 12)
      HStack(spacing: 6) {
        ForEach(0..<7, id: \.self) { _ in
          skeleton(height: 44, radius: 12)
        }
      }
      HStack(spacing: 11) {
        skeleton(height: 72, radius: 16)
        skeleton(height: 72, radius: 16)
      }
      skeleton(height: 128, radius: 16)
    }
    .accessibilityLabel("正在加载今日计划")
  }

  private func skeleton(height: CGFloat, radius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: radius)
      .fill(Color.MeetPR.textGhost.opacity(0.34))
      .frame(maxWidth: .infinity)
      .frame(height: height)
  }
}
