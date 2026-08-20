// swiftlint:disable type_body_length
import Analytics
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// The coached student's black-gold v3 今日 screen.
///
/// The screen composes existing plan, feedback, e1RM, profile, and notification sources.
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let feedbackViewModel: FeedbackInboxViewModel
  private let notifications: StudentNotificationsCoordinator?
  private let onStartWorkout: (TodayWorkoutPlanHandoff?) -> Void
  private let onStartWorkoutFrameChange: (CGRect) -> Void
  private let isStartWorkoutHidden: Bool
  private let onOpenPlanNotification: () -> Void
  private let planProjectionUpdate: StudentPlanView?
  private let onPlanChanged: (StudentPlanView) -> Void
  private let todayReloadToken: Int
  private let todayVolatileReloadToken: Int
  private let onFullReload: () -> Void
  @Binding private var pushedConversationID: UUID?

  @State private var weekViewModel: WeekOverviewViewModel
  @State private var e1rmTrendViewModel: DashboardE1RMTrendViewModel
  @State private var profileMetricsViewModel: DashboardProfileMetricsViewModel
  @State private var showsNotifications = false
  @State private var conversationID: UUID?
  @State private var completionErrorMessage: String?
  @State private var isUpdatingCompletion = false
  @State private var isFeedbackExpanded = false
  @State private var newPRCount = 0
  @State private var hasAttemptedWeekLoad = false

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    e1rm: any E1RMRepository,
    feedbackViewModel: FeedbackInboxViewModel,
    notifications: StudentNotificationsCoordinator? = nil,
    onStartWorkout: @escaping (TodayWorkoutPlanHandoff?) -> Void,
    onStartWorkoutFrameChange: @escaping (CGRect) -> Void = { _ in },
    isStartWorkoutHidden: Bool = false,
    onOpenPlanNotification: @escaping () -> Void = {},
    todayReloadToken: Int = 0,
    todayVolatileReloadToken: Int = 0,
    planProjectionUpdate: StudentPlanView? = nil,
    onFullReload: @escaping () -> Void = {},
    onPlanChanged: @escaping (StudentPlanView) -> Void = { _ in },
    pushedConversationID: Binding<UUID?> = .constant(nil)
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.feedbackViewModel = feedbackViewModel
    self.notifications = notifications
    self.onStartWorkout = onStartWorkout
    self.onStartWorkoutFrameChange = onStartWorkoutFrameChange
    self.isStartWorkoutHidden = isStartWorkoutHidden
    self.onOpenPlanNotification = onOpenPlanNotification
    self.todayReloadToken = todayReloadToken
    self.todayVolatileReloadToken = todayVolatileReloadToken
    self.planProjectionUpdate = planProjectionUpdate
    self.onFullReload = onFullReload
    self.onPlanChanged = onPlanChanged
    self._pushedConversationID = pushedConversationID
    self._weekViewModel = State(initialValue: WeekOverviewViewModel(plans: plans, logs: logs))
    self._e1rmTrendViewModel = State(
      initialValue: DashboardE1RMTrendViewModel(
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding
      )
    )
    self._profileMetricsViewModel = State(
      initialValue: DashboardProfileMetricsViewModel(onboarding: onboarding)
    )
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        DashboardTodayScreen(
          model: screenModel,
          feedbackViewModel: feedbackViewModel,
          isFeedbackExpanded: $isFeedbackExpanded,
          onOpenNotifications: {
            if notifications != nil {
              showsNotifications = true
            }
          },
          onStartWorkout: startCursorWorkout,
          isUpdatingCompletion: isUpdatingCompletion,
          onUndoCompletion: { dayID in
            Task { await undoCompletion(dayID: dayID) }
          },
          onMessageCoach: { showsNotifications = true },
          onRetryWeek: {
            Task { await reload() }
          },
          onRetryMetrics: {
            Task { await profileMetricsViewModel.load(studentID: studentID) }
          },
          onRetryTrend: {
            Task { await e1rmTrendViewModel.load(studentID: studentID) }
          }
        )
      }
      .scrollIndicators(.hidden)
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .modifier(notificationHost)
      .refreshable {
        await reload()
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if let day = stickyStartDay {
          DashboardPrimaryAction(
            day: day,
            onStart: startCursorWorkout,
            onStartFrameChange: onStartWorkoutFrameChange,
            isStartHidden: isStartWorkoutHidden
          )
          .padding(.horizontal, 20)
          .padding(.top, 10)
          .padding(.bottom, 8)
          .background(Color.MeetPR.bgBase)
          .overlay(alignment: .top) {
            Rectangle()
              .fill(Color.MeetPR.borderSubtle)
              .frame(height: 1)
          }
        }
      }
    }
    .background(Color.MeetPR.bgBase)
    .task {
      await loadIfNeeded()
      onFullReload()
      if let planID = weekViewModel.plan?.cycleID {
        Analytics.shared.planViewed(planID: planID)
      }
    }
    .onChange(of: todayReloadToken) { _, _ in
      Task { await reload() }
    }
    .onChange(of: todayVolatileReloadToken) { _, _ in
      Task { await reloadVolatileData() }
    }
    .onChange(of: planProjectionUpdate) { _, plan in
      guard let plan else { return }
      Task { await weekViewModel.applyPlanProjection(plan, studentID: studentID) }
    }
    .task(id: pushedConversationID) {
      await openPushedConversationIfNeeded()
    }
    .alert(StudentStrings.localized(.dashboardView001), isPresented: completionErrorPresented) {
      Button(StudentStrings.localized(.dashboardView002), role: .cancel) {
        completionErrorMessage = nil
      }
    } message: {
      Text(completionErrorMessage ?? "")
    }
  }

  private var screenModel: DashboardTodayScreenModel {
    DashboardTodayScreenModel(
      weekIndex: weekData?.weekIndex,
      planStartDate: weekViewModel.planStartDate,
      planEndDate: weekViewModel.plan?.endDate,
      days: weekData?.days ?? [],
      cycleDays: weekViewModel.cycleDays,
      logs: weekData?.logs ?? [],
      feedbackItems: feedbackViewModel.items,
      isFeedbackLoaded: feedbackViewModel.hasFinishedLoading,
      trendState: e1rmTrendViewModel.state,
      metricsState: profileMetricsViewModel.state,
      coachName: notifications?.activeCoach?.coachDisplayName
        ?? StudentStrings.localized(.dashboardView003),
      newPRCount: newPRCount,
      showsNotifications: notifications != nil,
      notificationUnreadCount: notifications?.totalUnreadCount ?? 0,
      weekContentState: DashboardWeekContentState.resolve(
        weekViewModel.state,
        hasAttemptedLoad: hasAttemptedWeekLoad
      ),
      now: Date()
    )
  }

  private var weekData: DashboardWeekData? {
    if case .loaded(let days, let logs, let weekIndex) = weekViewModel.state {
      return DashboardWeekData(days: days, logs: logs, weekIndex: weekIndex)
    }
    return nil
  }

  private var stickyStartDay: StudentPlanDay? {
    let days = weekViewModel.cycleDays
    guard DashboardTodayPresentation.completedToday(in: days, now: Date()) == nil else {
      return nil
    }
    return StudentPlanSequence(days: days).cursorDay
  }

  private func startCursorWorkout() {
    guard let plan = weekViewModel.plan else {
      onStartWorkout(nil)
      return
    }
    let sequence = StudentPlanSequence(days: plan.days)
    let target = sequence.cursorDay ?? sequence.orderedDays.last
    onStartWorkout(
      target.map {
        TodayWorkoutPlanHandoff(
          plan: plan,
          dayID: $0.id,
          existingLogs: weekData?.logs ?? []
        )
      }
    )
  }

  @MainActor
  private func undoCompletion(dayID: UUID) async {
    guard !isUpdatingCompletion else { return }
    isUpdatingCompletion = true
    defer { isUpdatingCompletion = false }
    do {
      try await plans.undoDayCompletion(id: dayID, studentID: studentID)
      await weekViewModel.load(studentID: studentID, serverAuthoritative: true)
      if let plan = weekViewModel.plan {
        onPlanChanged(plan)
      }
    } catch let error as PlanDayCompletionError {
      completionErrorMessage = error.localizedMessage
    } catch {
      completionErrorMessage = StudentStrings.localized(.dashboardView004)
    }
  }

  private var completionErrorPresented: Binding<Bool> {
    Binding(
      get: { completionErrorMessage != nil },
      set: { if !$0 { completionErrorMessage = nil } }
    )
  }

  private func loadIfNeeded() async {
    async let weekLoad: Void = loadWeekIfNeeded()
    async let notificationLoad: Void = loadNotificationsIfNeeded()
    async let trendLoad: Void = loadTrendIfNeeded()
    async let metricsLoad: Void = loadMetricsIfNeeded()
    _ = await (weekLoad, notificationLoad, trendLoad, metricsLoad)
    await loadNewPRCount()
  }

  private func openPushedConversationIfNeeded() async {
    guard let requestedID = pushedConversationID else { return }
    guard let notifications else {
      pushedConversationID = nil
      return
    }
    let result = await notifications.openCoachConversation()
    guard pushedConversationID == requestedID else { return }
    if case .opened(let openedID) = result, openedID == requestedID {
      conversationID = openedID
    }
    pushedConversationID = nil
  }

  private func reload() async {
    hasAttemptedWeekLoad = true
    async let weekLoad: Void = weekViewModel.load(
      studentID: studentID,
      serverAuthoritative: true
    )
    async let notificationLoad: Void = reloadNotifications()
    async let trendLoad: Void = e1rmTrendViewModel.load(studentID: studentID)
    async let metricsLoad: Void = profileMetricsViewModel.load(studentID: studentID)
    _ = await (weekLoad, notificationLoad, trendLoad, metricsLoad)
    await loadNewPRCount()
    onFullReload()
  }

  private func reloadVolatileData() async {
    async let logLoad: Void = weekViewModel.refreshLogs(studentID: studentID)
    async let notificationLoad: Void = reloadVolatileNotifications()
    _ = await (logLoad, notificationLoad)
    await loadNewPRCount()
  }

  private func loadWeekIfNeeded() async {
    guard weekViewModel.state == .idle else { return }
    hasAttemptedWeekLoad = true
    await weekViewModel.load(studentID: studentID, serverAuthoritative: true)
  }

  private func loadNotificationsIfNeeded() async {
    guard notifications == nil, feedbackViewModel.state == .idle else { return }
    await feedbackViewModel.load(studentID: studentID)
  }

  private func loadTrendIfNeeded() async {
    guard e1rmTrendViewModel.state == .idle else { return }
    await e1rmTrendViewModel.load(studentID: studentID)
  }

  private func loadMetricsIfNeeded() async {
    guard profileMetricsViewModel.state == .idle else { return }
    await profileMetricsViewModel.load(studentID: studentID)
  }

  private func reloadNotifications() async {
    if let notifications {
      await notifications.reload(studentID: studentID)
    } else {
      await feedbackViewModel.load(studentID: studentID)
    }
  }

  private func reloadVolatileNotifications() async {
    if let notifications {
      await notifications.reloadVolatile(studentID: studentID)
    } else {
      await feedbackViewModel.load(studentID: studentID)
    }
  }

  private func loadNewPRCount() async {
    // Weekly summary counts PR events inside the loaded plan week (same
    // range as the card's session/volume stats); the acknowledgement chain
    // went dormant with the celebration banner. No loaded week → no count.
    guard let days = weekData?.days.map(\.scheduledDate), let firstDay = days.min(),
      let lastDay = days.max()
    else {
      newPRCount = 0
      return
    }
    // Upper bound: PR events carry no plan-week identity, so clamp to the
    // end of the week's last plan day to mirror the card's other stats.
    let weekEnd = lastDay.addingTimeInterval(86_400)
    let events =
      (try? await e1rm.prEvents(studentId: studentID, since: firstDay)) ?? []
    newPRCount = events.filter { $0.occurredAt < weekEnd }.count
  }

  private var notificationHost: some ViewModifier {
    OptionalStudentNotificationHostModifier(
      coordinator: notifications,
      showsNotifications: $showsNotifications,
      conversationID: $conversationID,
      onOpenPlan: onOpenPlanNotification
    )
  }
}

// swiftlint:enable type_body_length
