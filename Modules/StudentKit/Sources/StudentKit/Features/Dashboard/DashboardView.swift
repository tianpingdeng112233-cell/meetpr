// swiftlint:disable type_body_length
import Analytics
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// The coached student's black-gold v3 今日 screen.
///
/// The screen composes existing week, feedback, e1RM, profile, notification,
/// and whole-plan-shift sources. It owns presentation and navigation only.
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardView: View {
  private let studentID: UUID
  private let canShiftPlanDays: Bool
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let feedbackViewModel: FeedbackInboxViewModel
  private let notifications: StudentNotificationsCoordinator?
  private let onStartWorkout: (TodayWorkoutPlanHandoff?) -> Void
  private let onStartWorkoutFrameChange: (CGRect) -> Void
  private let isStartWorkoutHidden: Bool
  private let onOpenPlanNotification: () -> Void
  private let onPlanChanged: () -> Void
  private let todayReloadToken: Int
  private let todayVolatileReloadToken: Int
  private let onFullReload: () -> Void

  @State private var weekViewModel: WeekOverviewViewModel
  @State private var e1rmTrendViewModel: DashboardE1RMTrendViewModel
  @State private var profileMetricsViewModel: DashboardProfileMetricsViewModel
  @State private var showsNotifications = false
  @State private var conversationID: UUID?
  @State private var dayShiftAlert: DashboardDayShiftAlert?
  @State private var shiftProposal: PlanShiftProposal?
  @State private var isUpdatingDayShift = false
  @State private var selectedDate: Date?
  @State private var isFeedbackExpanded = false
  @State private var newPRCount = 0

  public init(
    studentID: UUID,
    canShiftPlanDays: Bool,
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
    onFullReload: @escaping () -> Void = {},
    onPlanChanged: @escaping () -> Void = {}
  ) {
    self.studentID = studentID
    self.canShiftPlanDays = canShiftPlanDays
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
    self.onFullReload = onFullReload
    self.onPlanChanged = onPlanChanged
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
          selectedDate: $selectedDate,
          isFeedbackExpanded: $isFeedbackExpanded,
          onOpenNotifications: {
            if notifications != nil {
              showsNotifications = true
            }
          },
          onStartWorkout: {
            onStartWorkout(
              weekViewModel.plan.map {
                TodayWorkoutPlanHandoff(
                  plan: $0,
                  date: Date(),
                  existingLogs: weekData?.logs ?? []
                )
              }
            )
          },
          onStartWorkoutFrameChange: onStartWorkoutFrameChange,
          isStartWorkoutHidden: isStartWorkoutHidden,
          onShiftPlan: proposeShiftToday,
          onUndoShift: {
            dayShiftAlert = .confirmCancel(Date())
          },
          onMessageCoach: { showsNotifications = true }
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
    #if os(iOS)
      .fullScreenCover(item: $shiftProposal) { proposal in
        PostponeConfirmationOverlay(
          tomorrow: shiftTargetDate,
          isConfirming: isUpdatingDayShift,
          onCancel: { shiftProposal = nil },
          onConfirm: {
            shiftProposal = nil
            Task { await shiftToday(proposal) }
          }
        )
        .presentationBackground(.clear)
      }
    #else
      .sheet(item: $shiftProposal) { proposal in
        PostponeConfirmationOverlay(
          tomorrow: shiftTargetDate,
          isConfirming: isUpdatingDayShift,
          onCancel: { shiftProposal = nil },
          onConfirm: {
            shiftProposal = nil
            Task { await shiftToday(proposal) }
          }
        )
      }
    #endif
    .alert(item: $dayShiftAlert) { alert in
      switch alert {
      case .confirmCancel(let returnDate):
        Alert(
          title: Text("撤销顺延？"),
          message: Text("课程会回到\(dayShiftDateText(returnDate))。"),
          primaryButton: .destructive(Text("撤销顺延")) {
            Task { await cancelShift() }
          },
          secondaryButton: .cancel(Text("保留顺延"))
        )
      case .message(let title, let message):
        Alert(
          title: Text(title),
          message: Text(message),
          dismissButton: .default(Text("知道了"))
        )
      }
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
      trendRows: trendPresentation?.rows ?? [],
      metrics: profileMetricsViewModel.metrics,
      coachName: notifications?.activeCoach?.coachDisplayName ?? "教练",
      newPRCount: newPRCount,
      showsNotifications: notifications != nil,
      notificationUnreadCount: notifications?.totalUnreadCount ?? 0,
      canShiftPlanDays: canShiftPlanDays,
      canUndoPlanShift: canUndoPlanShift,
      isUpdatingDayShift: isUpdatingDayShift,
      isLoading: weekViewModel.state == .idle || weekViewModel.state == .loading,
      now: Date()
    )
  }

  private var weekData: DashboardWeekData? {
    if case .loaded(let days, let logs, let weekIndex) = weekViewModel.state {
      return DashboardWeekData(days: days, logs: logs, weekIndex: weekIndex)
    }
    return nil
  }

  private var trendPresentation: DashboardE1RMTrendPresentation? {
    if case .loaded(let presentation) = e1rmTrendViewModel.state {
      return presentation
    }
    return nil
  }

  private var canUndoPlanShift: Bool {
    guard canShiftPlanDays, let plan = weekViewModel.plan else { return false }
    return PlanDayShiftLogic.canUndo(
      latestShiftCreatedAt: plan.latestShiftCreatedAt,
      now: Date()
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

  private func reload() async {
    async let weekLoad: Void = weekViewModel.load(studentID: studentID)
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
    await weekViewModel.load(studentID: studentID)
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
    guard let days = weekData?.days.map(\.date), let firstDay = days.min(),
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

  private func proposeShiftToday() {
    guard let plan = weekViewModel.plan,
      let proposal = PlanDayShiftLogic.proposal(
        plan: plan,
        today: Date()
      )
    else {
      return
    }
    shiftProposal = proposal
  }

  private var shiftTargetDate: Date {
    PlanCalendarDayIdentity.utcCalendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
  }

  @MainActor
  private func shiftToday(_ proposal: PlanShiftProposal) async {
    isUpdatingDayShift = true
    defer { isUpdatingDayShift = false }
    do {
      let result = try await plans.shiftPlan(id: proposal.planID, studentID: studentID)
      await weekViewModel.load(studentID: studentID)
      onPlanChanged()
      if let message = PlanDayShiftLogic.cumulativeShiftMessage(
        totalShiftDays: result.totalShiftDays
      ) {
        dayShiftAlert = .message(title: "顺延成功", text: message)
      }
    } catch {
      dayShiftAlert = .message(
        title: "无法顺延",
        text: PlanDayShiftLogic.errorMessage(for: error, operation: .shift)
      )
    }
  }

  @MainActor
  private func cancelShift() async {
    isUpdatingDayShift = true
    defer { isUpdatingDayShift = false }
    do {
      guard let planID = weekViewModel.plan?.cycleID else { return }
      try await plans.cancelPlanShift(id: planID, studentID: studentID)
      await weekViewModel.load(studentID: studentID)
      onPlanChanged()
    } catch {
      dayShiftAlert = .message(
        title: "无法撤销",
        text: PlanDayShiftLogic.errorMessage(for: error, operation: .cancel)
      )
    }
  }

  private func dayShiftDateText(_ date: Date) -> String {
    date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
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

private enum DashboardDayShiftAlert: Identifiable {
  case confirmCancel(Date)
  case message(title: String, text: String)

  var id: String {
    switch self {
    case .confirmCancel(let date): "cancel-\(date.timeIntervalSince1970)"
    case .message(let title, let text): "message-\(title)-\(text)"
    }
  }
}
// swiftlint:enable type_body_length
