// swiftlint:disable file_length type_body_length large_tuple
import Analytics
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// Student home (今日), reskinned to the design's `StudentPlanView` layout:
/// a `WxDy` large title, this-week progress bar, the latest coach feedback,
/// a Mon–Sun S/B/D week grid (tap to select a day), the selected day's e1RM
/// growth curve, and the start-today CTA. Composes the existing week / feedback
/// / e1RM / profile-metrics view models — no new persistence.
@available(iOS 17.0, macOS 14.0, *)
public struct DashboardView: View {
  private let studentID: UUID
  private let canShiftPlanDays: Bool
  private let plans: any StudentPlanRepository
  private let onboarding: any OnboardingProfileReading
  private let e1rm: any E1RMRepository
  private let feedbackViewModel: FeedbackInboxViewModel
  private let evaluationSummaryViewModel: StudentEvaluationSummaryViewModel?
  private let notifications: StudentNotificationsCoordinator?
  private let evaluationNavigationPulse: Int
  private let onStartWorkout: () -> Void
  private let onSeeAllFeedback: () -> Void
  private let onOpenEvaluation: () -> Void
  private let onPlanChanged: () -> Void
  /// Bumped by the parent tab container each time 今日 becomes the active tab, so
  /// the home screen re-reads week/e1RM data logged in the 训练 tab (the view
  /// models cache a one-shot snapshot; without this, a completed workout keeps
  /// showing 继续 on return).
  private let todayReloadToken: Int
  @State private var weekViewModel: WeekOverviewViewModel
  @State private var e1rmTrendViewModel: DashboardE1RMTrendViewModel
  @State private var profileMetricsViewModel: DashboardProfileMetricsViewModel
  @State private var showsNotifications = false
  @State private var showsEvaluationSummary = false
  @State private var conversationID: UUID?
  @State private var dayShiftAlert: DashboardDayShiftAlert?
  @State private var isUpdatingDayShift = false
  /// Day whose growth curve is shown. `nil` ⇒ today (the default selection).
  @State private var selectedDate: Date?
  /// Manual E1RM-card lift pick; `nil` follows the selected day.
  @State private var liftOverride: LiftFamily?
  @Environment(\.colorScheme) private var colorScheme

  public init(
    studentID: UUID,
    canShiftPlanDays: Bool,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    e1rm: any E1RMRepository,
    feedbackViewModel: FeedbackInboxViewModel,
    evaluationSummaryViewModel: StudentEvaluationSummaryViewModel? = nil,
    notifications: StudentNotificationsCoordinator? = nil,
    evaluationNavigationPulse: Int = 0,
    onStartWorkout: @escaping () -> Void,
    onSeeAllFeedback: @escaping () -> Void,
    onOpenEvaluation: @escaping () -> Void = {},
    todayReloadToken: Int = 0,
    onPlanChanged: @escaping () -> Void = {}
  ) {
    self.studentID = studentID
    self.canShiftPlanDays = canShiftPlanDays
    self.plans = plans
    self.onboarding = onboarding
    self.e1rm = e1rm
    self.feedbackViewModel = feedbackViewModel
    self.evaluationSummaryViewModel = evaluationSummaryViewModel
    self.notifications = notifications
    self.evaluationNavigationPulse = evaluationNavigationPulse
    self.onStartWorkout = onStartWorkout
    self.onSeeAllFeedback = onSeeAllFeedback
    self.onOpenEvaluation = onOpenEvaluation
    self.todayReloadToken = todayReloadToken
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
        VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
          header

          if let evaluationSummaryViewModel {
            EvaluationCompletedCard(viewModel: evaluationSummaryViewModel)
              .padding(.top, MeetPRSpacing.space4)
              .meetPRRiseIn(index: 1)
          }

          weekProgressBar
            .padding(.top, MeetPRSpacing.space4)
            .meetPRRiseIn(index: 2)

          // Handoff §4.1 order: week strip, coach feedback, weight/meet tiles,
          // E1RM curve, then the primary CTA closes the screen.
          weekToggle
            .padding(.top, MeetPRSpacing.space5)
          weekGrid
            .padding(.top, MeetPRSpacing.space2)
            .meetPRRiseIn(index: 3)

          if let feedback = latestFeedback {
            todayFeedbackCard(feedback)
              .padding(.top, MeetPRSpacing.space4)
              .meetPRRiseIn(index: 4)
          }

          if let metrics = profileMetricsViewModel.metrics {
            DashboardProfileMetricsView(metrics: metrics)
              .padding(.top, MeetPRSpacing.space4)
              .meetPRRiseIn(index: 5)
          }

          liftCard
            .padding(.top, MeetPRSpacing.space5)
            .meetPRRiseIn(index: 6)

          startButton
            .padding(.top, MeetPRSpacing.space4)
            .meetPRRiseIn(index: 7)
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.point6)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(isPresented: $showsEvaluationSummary) {
        if let summary = evaluationSummaryViewModel?.summary {
          EvaluationSummaryView(summary: summary) {
            evaluationSummaryViewModel?.markRead()
          }
        }
      }
      .modifier(notificationHost)
      .refreshable {
        await reload()
      }
    }
    .task {
      await loadIfNeeded()
      if let planID = weekViewModel.plan?.cycleID {
        Analytics.shared.planViewed(planID: planID)
      }
    }
    .onChange(of: todayReloadToken) { _, _ in
      Task { await reload() }
    }
    .task(id: evaluationNavigationPulse) {
      guard evaluationNavigationPulse > 0 else { return }
      showsEvaluationSummary = true
    }
    .alert(item: $dayShiftAlert) { alert in
      switch alert {
      case .confirmShift(let proposal):
        Alert(
          title: Text("把整份计划往后顺延一天？"),
          message: Text(PlanDayShiftLogic.confirmationMessage(for: proposal)),
          primaryButton: .default(Text("确认顺延")) {
            Task { await shiftToday(proposal) }
          },
          secondaryButton: .cancel(Text("取消"))
        )
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

  // MARK: - Header

  private var header: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      HStack(spacing: MeetPRSpacing.sm) {
        MeetPRMark(size: 32)
        Text(Date(), format: .dateTime.month().day().weekday(.wide))
          .font(.MeetPR.mono(size: 12, weight: .medium))
          .tracking(0.72)
          .foregroundStyle(Color.MeetPR.textMuted)
        Spacer()
      }

      HStack(alignment: .center) {
        Text(titleLabel)
          .font(.MeetPR.display(size: 54, weight: .extraBold))
          .tracking(-1.4)
          .foregroundStyle(Color.MeetPR.displayText)
          // The mockups only cast the display-title shadow on dark; on the
          // light page it would read as smudged ink.
          .shadow(
            color: colorScheme == .dark ? .black.opacity(0.55) : .clear,
            radius: 2, y: 3
          )
        Spacer()
        if let notifications {
          StudentNotificationBell(coordinator: notifications) {
            showsNotifications = true
          }
        }
      }
    }
    .meetPRRiseIn(index: 0)
  }

  // MARK: - Week progress bar

  private var weekProgressBar: some View {
    GoldProgressBar(fraction: weekProgressFraction)
  }

  /// Overall week completion: mean of per-training-day set fractions.
  private var weekProgressFraction: Double {
    let values = weekProgressValues
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
  }

  /// One segment per training day in the week (rest days excluded), each filled
  /// by that day's set-completion fraction. Falls back to a single empty segment.
  private var weekProgressValues: [Double] {
    guard let data = weekData else { return [0] }
    let logs = data.logs
    let values = data.days
      .filter { !$0.exercises.isEmpty }
      .map { day -> Double in
        let progress = TrainingDayProgress(day: day, logs: logs)
        guard progress.total > 0 else { return 0 }
        return Double(progress.completed) / Double(progress.total)
      }
    return values.isEmpty ? [0] : values
  }

  // MARK: - Today feedback card

  private func todayFeedbackCard(_ item: CoachFeedback) -> some View {
    Button(action: onSeeAllFeedback) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        HStack(spacing: MeetPRSpacing.space2) {
          if item.readAt == nil {
            // An inline "new here" marker, not a count badge: the mockups draw
            // it in gold on both themes.
            Circle().fill(MeetPRSemanticTone.inProgress.color).frame(width: 7, height: 7)
          }
          Text(feedbackEyebrow(item))
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.gold500)
        }
        Text(item.text)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .multilineTextAlignment(.leading)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, MeetPRSpacing.point10)
        Text(feedbackFooter(item))
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.top, MeetPRSpacing.space2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        HStack(spacing: MeetPRSpacing.zero) {
          Rectangle()
            .fill(Color.MeetPR.gold500)
            .frame(width: 3)
          Spacer(minLength: 0)
        }
      }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private func feedbackEyebrow(_ item: CoachFeedback) -> String {
    guard let day = item.dayDate else { return "教练反馈" }
    return "教练反馈 · " + TodayFormat.shortWeekday.string(from: day)
  }

  private func feedbackFooter(_ item: CoachFeedback) -> String {
    "教练 · " + TodayFormat.time.string(from: item.postedAt) + " · 在「成长」查看全部反馈 →"
  }

  // MARK: - Week grid (Mon–Sun, S/B/D)

  private var weekToggle: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      Text("本周")
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
  }

  private var weekGrid: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      ForEach(0..<7, id: \.self) { offset in
        let date = weekday(offset)
        dayCell(offset: offset, date: date, day: planDay(on: date))
      }
    }
  }

  private func dayCell(offset: Int, date: Date, day: StudentPlanDay?) -> some View {
    MeetPRDayChip(
      weekday: TodayFormat.weekdayLetter(offset),
      date: Calendar.current.component(.day, from: date),
      state: dayChipState(for: date, day: day),
      isSelected: Calendar.current.isDate(date, inSameDayAs: effectiveSelectedDate)
    ) {
      selectedDate = date
    }
  }

  /// Rest days are never "missed": only a planned day without a completed
  /// session goes red, per the handoff spec's DayChip rule.
  private func dayChipState(for date: Date, day: StudentPlanDay?) -> MeetPRDayChip.DayState {
    if Calendar.current.isDateInToday(date) { return .today }
    guard day != nil else { return .rest }
    let isPast = date < Calendar.current.startOfDay(for: Date())
    guard isPast else { return .future }
    let complete =
      TrainingDayProgress(day: day, logs: weekData?.logs ?? []).state == .complete
    return complete ? .done : .missed
  }

  // MARK: - Selected-day lift card

  private var liftCard: some View {
    NavigationLink {
      GrowthCurveView(
        studentID: studentID,
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding
      )
    } label: {
      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        liftCardContent
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
          Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  @ViewBuilder
  private var liftCardContent: some View {
    let rows = selectedTrendRows
    if !rows.isEmpty {
      if switchableFamilies.count > 1 {
        liftSwitcher
          .padding(.bottom, MeetPRSpacing.space3)
      }
      VStack(alignment: .leading, spacing: MeetPRSpacing.space6) {
        ForEach(rows) { row in
          liftTrendBlock(row)
        }
      }
      Text(liftCardFooter())
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.textTertiary)
        .padding(.top, MeetPRSpacing.space3)
    } else {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
        Text("成长曲线")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.gold500)
        Text(selectedFamilies.isEmpty ? "选中训练日查看对应成长曲线" : "练几次就有趋势了")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
      }
    }
  }

  /// One hero block (label + big e1RM + 90-day delta + sparkline) for a single
  /// lift family. Stacked one per family trained on the selected day, so an SB
  /// day shows a squat curve above a bench curve.
  @ViewBuilder
  private func liftTrendBlock(_ row: DashboardE1RMTrendRow) -> some View {
    let now = Date()
    VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
          Text("\(row.family.studentDisplayName) E1RM · \(trendPeriodLabel(row, now: now))")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.gold500)
          HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point6) {
            Text(StudentFormatting.kilograms(row.displayPoint(now: now)?.e1RMKg ?? 0))
              .font(.MeetPR.display(size: 30, weight: .extraBold).monospacedDigit())
              .foregroundStyle(Color.MeetPR.textPrimary)
            Text("KG")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .heavy))
              .foregroundStyle(Color.MeetPR.gold500)
          }
          .padding(.top, MeetPRSpacing.space1)
        }
        Spacer()
        if let deltaKg = row.trendDeltaKg {
          let delta = deltaLabel(deltaKg)
          Text(delta.text)
            .font(.MeetPR.system(size: MeetPRFontMetrics.size13, design: .monospaced))
            .foregroundStyle(delta.color)
        }
      }
      Sparkline(
        points: row.sparklinePoints(),
        viewBox: CGSize(width: 600, height: 120),
        showsPointDots: true
      )
      .frame(height: 110)
      .padding(.top, MeetPRSpacing.space3)
    }
  }

  private func liftCardFooter() -> String {
    let names = selectedTrendRows.map(\.family.studentDisplayName).joined(separator: "、")
    return "选中 " + TodayFormat.shortWeekday.string(from: effectiveSelectedDate)
      + " · \(names)日"
  }

  private func trendPeriodLabel(_ row: DashboardE1RMTrendRow, now: Date) -> String {
    row.displaysHistoricalBest(now: now)
      ? "历史最佳" : "\(DashboardE1RMTrendViewModel.chartWindowDays) 天"
  }

  // MARK: - Start CTA

  @ViewBuilder
  private var startButton: some View {
    let progress = TrainingDayProgress(day: todayDay, logs: weekData?.logs ?? [])
    VStack(spacing: MeetPRSpacing.space2) {
      startButtonPrimary(progress)

      if canShiftPlanDays,
        progress.state == .notStarted,
        let todayDay,
        dayShiftCalendar.isDate(todayDay.date, inSameDayAs: Date()),
        !hasAnyLog(for: todayDay, in: weekData?.logs ?? [])
      {
        Button("今天有事") {
          proposeShiftToday()
        }
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
            Color.MeetPR.borderDefault, lineWidth: 1)
        }
        .disabled(isUpdatingDayShift)
      }

      if canUndoPlanShift {
        Button("撤销顺延") {
          dayShiftAlert = .confirmCancel(Date())
        }
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.MeetPR.goldSoft)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
        .disabled(isUpdatingDayShift)
      }
    }
  }

  @ViewBuilder
  private func startButtonPrimary(_ progress: TrainingDayProgress) -> some View {
    switch progress.state {
    case .noPlan:
      HStack(spacing: MeetPRSpacing.point10) {
        Image(systemName: "bed.double.fill").foregroundStyle(Color.MeetPR.textSecondary)
        Text("今日休息").font(Font.MeetPR.bodyEmphasis).foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
          Color.MeetPR.borderDefault, lineWidth: 1)
      }
    default:
      BrandPrimaryButton(
        startButtonLabel(progress),
        // Handoff §4.1 fixes the subtitle to the brand line (David 2026-07-26).
        subtitle: "蹲 · 推 · 拉",
        systemImage: "play.fill",
        showsShimmer: true,
        isFullWidth: true,
        action: onStartWorkout
      )
    }
  }

  private func startButtonLabel(_ progress: TrainingDayProgress) -> String {
    let lift = todayDay.flatMap(mainFamily)?.studentDisplayName ?? "训练"
    let label = todayLabel
    switch progress.state {
    case .complete: return "今日已完成 · 查看"
    case .partial: return "继续 \(label) · \(lift)"
    default: return "开始 \(label) · \(lift)"
    }
  }

  // MARK: - Derived data

  private var weekData: (days: [StudentPlanDay], logs: [StudentSetLog], weekIndex: Int)? {
    if case .loaded(let days, let logs, let weekIndex) = weekViewModel.state {
      return (days, logs, weekIndex)
    }
    return nil
  }

  /// Monday of the week containing today (Mon-based offset 0…6).
  private func weekday(_ offset: Int) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let weekday = calendar.component(.weekday, from: today)  // 1=Sun…7=Sat
    let mondayOffset = (weekday + 5) % 7  // days since Monday
    let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) ?? today
    return calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
  }

  private func planDay(on date: Date) -> StudentPlanDay? {
    weekData?.days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
  }

  /// Ordered S→B→D families on a day (main lifts + variations, deduped) — the
  /// week-grid badge source.
  private func dayFamilies(_ day: StudentPlanDay) -> [LiftFamily] {
    MainLiftExerciseFamilyResolver.families(in: day)
  }

  /// The day's primary family (first in S→B→D order) — drives the selected-day
  /// growth curve and the start-CTA label, which are single-lift by design.
  private func mainFamily(_ day: StudentPlanDay) -> LiftFamily? {
    dayFamilies(day).first
  }

  private func liftLetter(_ family: LiftFamily) -> String {
    switch family {
    case .squat: "S"
    case .bench: "B"
    case .deadlift: "D"
    }
  }

  private var effectiveSelectedDate: Date {
    selectedDate ?? Date()
  }

  /// All main-lift families trained on the selected day, in S→B→D order.
  private var selectedFamilies: [LiftFamily] {
    planDay(on: effectiveSelectedDate).map(dayFamilies) ?? []
  }

  /// Selected-day families that actually have e1RM history to plot, in S→B→D
  /// order — the lift card renders one curve block per row.
  private var selectedTrendRows: [DashboardE1RMTrendRow] {
    // Handoff §4.1: the E1RM card is switchable between the three lifts. A
    // manual pick wins; otherwise it follows the selected day's lifts.
    if let liftOverride, let row = trendRow(for: liftOverride), !row.points.isEmpty {
      return [row]
    }
    return selectedFamilies.compactMap { family in
      guard let row = trendRow(for: family), !row.points.isEmpty else { return nil }
      return row
    }
  }

  /// Lift families that have any trend data, in S/B/D order — the switcher row.
  private var switchableFamilies: [LiftFamily] {
    MainLiftExerciseFamilyResolver.dashboardFamilies.filter { family in
      guard let row = trendRow(for: family) else { return false }
      return !row.points.isEmpty
    }
  }

  private var liftSwitcher: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      ForEach(switchableFamilies, id: \.self) { family in
        let active =
          liftOverride == family
          || (liftOverride == nil && selectedTrendRows.first?.family == family)
        Button {
          liftOverride = family
        } label: {
          Text(family.studentDisplayName)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
            .foregroundStyle(active ? Color.MeetPR.gold500 : Color.MeetPR.textFaint)
            .padding(.horizontal, MeetPRSpacing.space3)
            .padding(.vertical, MeetPRSpacing.point5)
            .background(active ? Color.MeetPR.goldSoft : Color.MeetPR.surfaceKey)
            .clipShape(Capsule())
            .overlay {
              if active {
                Capsule().stroke(Color.MeetPR.gold500.opacity(0.5), lineWidth: 1)
              }
            }
            // Keep the small pill tappable at the 44pt minimum.
            .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(PressScaleButtonStyle())
      }
      Spacer()
    }
  }

  private var todayDay: StudentPlanDay? {
    planDay(on: Date())
  }

  private var canUndoPlanShift: Bool {
    guard canShiftPlanDays, let plan = weekViewModel.plan else { return false }
    return PlanDayShiftLogic.canUndo(
      latestShiftCreatedAt: plan.latestShiftCreatedAt,
      now: Date()
    )
  }

  private var titleLabel: String {
    guard let weekIndex = weekData?.weekIndex else { return "今日" }
    let offset = mondayOffset(for: effectiveSelectedDate)
    return "W\(weekIndex)D\(offset + 1)"
  }

  private var todayLabel: String {
    guard let weekIndex = weekData?.weekIndex else { return "今日训练" }
    return "W\(weekIndex)D\(mondayOffset(for: Date()) + 1)"
  }

  private func mondayOffset(for date: Date) -> Int {
    let weekday = Calendar.current.component(.weekday, from: date)  // 1=Sun…7=Sat
    return (weekday + 5) % 7
  }

  private var trendPresentation: DashboardE1RMTrendPresentation? {
    if case .loaded(let presentation) = e1rmTrendViewModel.state { return presentation }
    return nil
  }

  private func trendRow(for family: LiftFamily) -> DashboardE1RMTrendRow? {
    trendPresentation?.rows.first { $0.family == family }
  }

  private func deltaLabel(_ kilograms: Double) -> (text: String, color: Color) {
    let sign = kilograms >= 0 ? "+" : "−"
    let color =
      kilograms > 0
      ? Color.MeetPR.success : (kilograms < 0 ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
    return ("\(sign)\(StudentFormatting.kilograms(abs(kilograms))) KG", color)
  }

  private var latestFeedback: CoachFeedback? {
    if case .loaded(let items) = feedbackViewModel.state {
      return items.max { $0.postedAt < $1.postedAt }
    }
    return nil
  }

  // MARK: - Loading

  private func loadIfNeeded() async {
    // Retry each dependency independently: cancellation resets only the
    // in-flight view model to `.idle`, so gating everything on the week model
    // would strand a later dependency without another retry.
    if weekViewModel.state == .idle {
      await weekViewModel.load(studentID: studentID)
      if notifications == nil {
        await evaluationSummaryViewModel?.load(studentID: studentID)
      }
    }
    if notifications == nil, feedbackViewModel.state == .idle {
      await feedbackViewModel.load(studentID: studentID)
    }
    if e1rmTrendViewModel.state == .idle {
      await e1rmTrendViewModel.load(studentID: studentID)
    }
    if profileMetricsViewModel.state == .idle {
      await profileMetricsViewModel.load(studentID: studentID)
    }
  }

  private func reload() async {
    await weekViewModel.load(studentID: studentID)
    if let notifications {
      await notifications.reload(studentID: studentID)
    } else {
      await feedbackViewModel.load(studentID: studentID)
      await evaluationSummaryViewModel?.load(studentID: studentID)
    }
    await e1rmTrendViewModel.load(studentID: studentID)
    await profileMetricsViewModel.load(studentID: studentID)
  }

  private func proposeShiftToday() {
    guard let plan = weekViewModel.plan,
      let proposal = PlanDayShiftLogic.proposal(plan: plan, today: Date())
    else { return }
    dayShiftAlert = .confirmShift(proposal)
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

  private func hasAnyLog(for day: StudentPlanDay, in logs: [StudentSetLog]) -> Bool {
    let exerciseIDs = Set(day.exercises.map(\.id))
    return logs.contains { exerciseIDs.contains($0.planExerciseID) }
  }

  private func dayShiftDateText(_ date: Date) -> String {
    date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
  }

  /// The backend defines "today" in UTC. Comparing with this calendar hides
  /// the action whenever the device's local date has already crossed midnight
  /// but UTC has not (notably 00:00–08:00 in China).
  private var dayShiftCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
  }

  private var notificationHost: some ViewModifier {
    OptionalStudentNotificationHostModifier(
      coordinator: notifications,
      showsNotifications: $showsNotifications,
      conversationID: $conversationID,
      onOpenPlan: onStartWorkout,
      onOpenFeedback: onSeeAllFeedback,
      onOpenEvaluation: onOpenEvaluation
    )
  }
}

private enum DashboardDayShiftAlert: Identifiable {
  case confirmShift(PlanShiftProposal)
  case confirmCancel(Date)
  case message(title: String, text: String)

  var id: String {
    switch self {
    case .confirmShift(let proposal): "shift-\(proposal.planID.uuidString)"
    case .confirmCancel(let date): "cancel-\(date.timeIntervalSince1970)"
    case .message(let title, let text): "message-\(title)-\(text)"
    }
  }
}

// MARK: - Local helpers

/// Small right-triangle filling the top-right corner (done-day marker).
private struct CornerTriangle: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

private enum TodayFormat {
  /// Mon-based offset (0…6) → 一/二/三/四/五/六/日.
  static func weekdayLetter(_ offset: Int) -> String {
    ["一", "二", "三", "四", "五", "六", "日"][min(max(offset, 0), 6)]
  }

  static let shortWeekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter
  }()

  static let time: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "HH:mm"
    return formatter
  }()
}
// swiftlint:enable file_length type_body_length large_tuple
