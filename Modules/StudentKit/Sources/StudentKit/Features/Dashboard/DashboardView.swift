// swiftlint:disable file_length type_body_length large_tuple
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
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let feedbackViewModel: FeedbackInboxViewModel
  private let evaluationSummaryViewModel: StudentEvaluationSummaryViewModel?
  private let onStartWorkout: () -> Void
  private let onSeeAllFeedback: () -> Void
  @State private var weekViewModel: WeekOverviewViewModel
  @State private var notificationsViewModel: DashboardNotificationsViewModel
  @State private var e1rmTrendViewModel: DashboardE1RMTrendViewModel
  @State private var profileMetricsViewModel: DashboardProfileMetricsViewModel
  @State private var showsNotifications = false
  @State private var showsEvaluationSummary = false
  @State private var dayChangeTick = 0
  /// Day whose growth curve is shown. `nil` ⇒ today (the default selection).
  @State private var selectedDate: Date?

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    e1rm: any E1RMRepository,
    feedbackViewModel: FeedbackInboxViewModel,
    evaluationSummaryViewModel: StudentEvaluationSummaryViewModel? = nil,
    onStartWorkout: @escaping () -> Void,
    onSeeAllFeedback: @escaping () -> Void
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.feedbackViewModel = feedbackViewModel
    self.evaluationSummaryViewModel = evaluationSummaryViewModel
    self.onStartWorkout = onStartWorkout
    self.onSeeAllFeedback = onSeeAllFeedback
    self._weekViewModel = State(initialValue: WeekOverviewViewModel(plans: plans, logs: logs))
    self._notificationsViewModel = State(
      initialValue: DashboardNotificationsViewModel(plans: plans)
    )
    self._e1rmTrendViewModel = State(
      initialValue: DashboardE1RMTrendViewModel(plans: plans, e1rm: e1rm)
    )
    self._profileMetricsViewModel = State(
      initialValue: DashboardProfileMetricsViewModel(onboarding: onboarding)
    )
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          header

          if let evaluationSummaryViewModel {
            EvaluationCompletedCard(viewModel: evaluationSummaryViewModel)
              .padding(.top, 16)
          }

          weekProgressBar
            .padding(.top, 16)

          if let feedback = latestFeedback {
            todayFeedbackCard(feedback)
              .padding(.top, 16)
          }

          weekToggle
            .padding(.top, 20)
          weekGrid
            .padding(.top, 8)

          liftCard
            .padding(.top, 20)

          startButton
            .padding(.top, 16)

          if let metrics = profileMetricsViewModel.metrics {
            DashboardProfileMetricsView(metrics: metrics)
              .padding(.top, 20)
              // Re-derives the countdown when the day flips (spec 049 §4).
              .id(dayChangeTick)
          }
        }
        .padding(16)
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
      .hideNavigationBar()
      .navigationDestination(isPresented: $showsEvaluationSummary) {
        if let summary = evaluationSummaryViewModel?.summary {
          EvaluationSummaryView(summary: summary) {
            evaluationSummaryViewModel?.markRead()
          }
        }
      }
      .sheet(isPresented: $showsNotifications) {
        NotificationCenterSheet(
          planNotice: notificationsViewModel.planNotice,
          feedbackUnreadCount: feedbackViewModel.unreadCount,
          evaluationUnreadCount: evaluationSummaryViewModel?.unreadBadgeCount ?? 0,
          onOpenPlan: openPlanNotification,
          onOpenFeedback: onSeeAllFeedback,
          onOpenEvaluation: { showsEvaluationSummary = true }
        )
        .presentationDetents([.medium])
      }
      .refreshable {
        await reload()
      }
    }
    .task {
      await loadIfNeeded()
    }
    // Coming back from the workout tab must show what was just logged —
    // the week slice reloads on every reappearance (spec 049 P0-1; the
    // stale `loadIfNeeded` gate was why a finished day still said 「继续」).
    .onAppear {
      guard weekViewModel.state != .idle else { return }
      Task { await weekViewModel.load(studentID: studentID) }
    }
    // 完成庆祝时刻: the day's only achievement feedback (spec 049 §1).
    .sensoryFeedback(.success, trigger: todayIsComplete) { _, newValue in newValue }
    // Countdown/date-derived rows recompute when the calendar day flips
    // (spec 049 §4) — the notification bumps a token the body reads.
    .onReceive(
      NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
        .receive(on: RunLoop.main)
    ) { _ in
      dayChangeTick += 1
    }
  }

  private var todayIsComplete: Bool {
    weekSnapshot?.progress(on: Date()).state == .complete
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(titleLabel)
        .font(.system(size: 36, weight: .heavy))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      notificationButton
    }
  }

  private var notificationButton: some View {
    Button(
      action: { showsNotifications = true },
      label: {
        ZStack(alignment: .topTrailing) {
          Image(systemName: hasUnreadNotifications ? "bell.badge" : "bell")
            .font(.system(size: 18))
            .foregroundStyle(Color.MeetPR.fgSecondary)
          if hasUnreadNotifications {
            Circle()
              .fill(Color.MeetPR.brandRed)
              .frame(width: 8, height: 8)
              .offset(x: 3, y: -3)
          }
        }
      }
    )
    .accessibilityLabel(hasUnreadNotifications ? "通知,有未读" : "通知")
  }

  // MARK: - Week progress bar

  private var weekProgressBar: some View {
    ProgressSegments(values: weekProgressValues, spacing: 6)
  }

  /// One segment per training day in the week (rest days excluded), each filled
  /// by that day's set-completion fraction. Falls back to a single empty segment.
  private var weekProgressValues: [Double] {
    weekSnapshot?.weekSegments() ?? [0]
  }

  // MARK: - Today feedback card

  private func todayFeedbackCard(_ item: CoachFeedback) -> some View {
    Button(action: onSeeAllFeedback) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          if item.readAt == nil {
            Circle().fill(Color.MeetPR.brandRed).frame(width: 7, height: 7)
          }
          Text(feedbackEyebrow(item))
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        Text(item.text)
          .font(.system(size: 14))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .multilineTextAlignment(.leading)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 10)
        Text(feedbackFooter(item))
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .padding(.top, 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.brandRed.opacity(0.3), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
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
    HStack(spacing: 6) {
      Text("本周")
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
  }

  private var weekGrid: some View {
    HStack(spacing: 6) {
      ForEach(0..<7, id: \.self) { offset in
        let date = weekday(offset)
        dayCell(offset: offset, date: date, day: planDay(on: date))
      }
    }
  }

  private func dayCell(offset: Int, date: Date, day: StudentPlanDay?) -> some View {
    let active = Calendar.current.isDate(date, inSameDayAs: effectiveSelectedDate)
    // All SBD families trained that day (main lifts + variations), ordered S→B→D
    // so the badge reads "SB" / "SBD" rather than a single lift.
    let families = day.map(dayFamilies) ?? []
    let isPast = date < Calendar.current.startOfDay(for: Date())
    let done =
      isPast && day != nil
      && weekSnapshot?.progress(for: day).state == .complete
    let liftText = families.isEmpty ? "—" : families.map(liftLetter).joined()

    return Button {
      selectedDate = date
    } label: {
      VStack(alignment: .leading) {
        Text(TodayFormat.weekdayLetter(offset))
          .font(.system(size: 11))
          .foregroundStyle(active ? Color.MeetPR.fgPrimary : Color.MeetPR.fgTertiary)
        Spacer(minLength: 0)
        Text(liftText)
          .font(.system(size: 18, weight: .bold, design: .monospaced))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .foregroundStyle(families.isEmpty ? Color.MeetPR.fgTertiary : Color.MeetPR.fgPrimary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .aspectRatio(1, contentMode: .fit)
      .padding(8)
      .background(active ? Color.MeetPR.surface2 : Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(active ? Color.MeetPR.fgPrimary : Color.MeetPR.border, lineWidth: 1)
      }
      .overlay(alignment: .topTrailing) {
        if done {
          CornerTriangle().fill(Color.MeetPR.brandRed).frame(width: 10, height: 10)
        }
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Selected-day lift card

  private var liftCard: some View {
    NavigationLink {
      GrowthCurveView(studentID: studentID, plans: plans, e1rm: e1rm)
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        liftCardContent
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var liftCardContent: some View {
    let rows = selectedTrendRows
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 24) {
        ForEach(rows) { row in
          liftTrendBlock(row)
        }
      }
      Text(liftCardFooter())
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .padding(.top, 12)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Text("成长曲线")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.brandRed)
        Text(selectedFamilies.isEmpty ? "选中训练日查看对应成长曲线" : "练几次就有趋势了")
          .font(.system(size: 14))
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
      }
    }
  }

  /// One hero block (label + big e1RM + 90-day delta + sparkline) for a single
  /// lift family. Stacked one per family trained on the selected day, so an SB
  /// day shows a squat curve above a bench curve.
  @ViewBuilder
  private func liftTrendBlock(_ row: DashboardE1RMTrendRow) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 0) {
          Text("\(row.family.studentDisplayName) E1RM · 90 天")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
          HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(StudentFormatting.kilograms(row.latestPoint?.e1RMKg ?? 0))
              .font(.system(size: 44, weight: .heavy).monospacedDigit())
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text("KG")
              .font(.system(size: 16, weight: .heavy))
              .foregroundStyle(Color.MeetPR.brandRed)
          }
          .padding(.top, 4)
        }
        Spacer()
        if let deltaKg = row.trendDeltaKg {
          let delta = deltaLabel(deltaKg)
          Text(delta.text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(delta.color)
        }
      }
      Sparkline(points: row.sparklinePoints(), viewBox: CGSize(width: 600, height: 120))
        .frame(height: 110)
        .padding(.top, 12)
    }
  }

  private func liftCardFooter() -> String {
    let names = selectedTrendRows.map(\.family.studentDisplayName).joined(separator: "、")
    return "选中 " + TodayFormat.shortWeekday.string(from: effectiveSelectedDate)
      + " · \(names)日"
  }

  // MARK: - Start CTA

  @ViewBuilder
  private var startButton: some View {
    let progress =
      weekSnapshot?.progress(for: todayDay)
      ?? TrainingDayProgress(day: todayDay, logs: [])
    switch progress.state {
    case .noPlan:
      HStack(spacing: 10) {
        Image(systemName: "bed.double.fill").foregroundStyle(Color.MeetPR.fgSecondary)
        Text("今日休息").font(Font.MeetPR.bodyEmphasis).foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
    default:
      Button(action: onStartWorkout) {
        Text(startButtonLabel(progress))
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.bg)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(Color.MeetPR.fgPrimary)
          .clipShape(.rect(cornerRadius: 12))
      }
      .buttonStyle(.plain)
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

  /// Single completion source (spec 049 §1) — every progress consumer on
  /// this screen derives from this snapshot, never from a private slice.
  private var weekSnapshot: TrainingWeekSnapshot? {
    weekData.map { TrainingWeekSnapshot(days: $0.days, logs: $0.logs) }
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
    selectedFamilies.compactMap { family in
      guard let row = trendRow(for: family), !row.points.isEmpty else { return nil }
      return row
    }
  }

  private var todayDay: StudentPlanDay? {
    planDay(on: Date())
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
      ? Color.MeetPR.green : (kilograms < 0 ? Color.MeetPR.brandRed : Color.MeetPR.fgSecondary)
    return ("\(sign)\(StudentFormatting.kilograms(abs(kilograms))) KG", color)
  }

  private var latestFeedback: CoachFeedback? {
    if case .loaded(let items) = feedbackViewModel.state {
      return items.max { $0.postedAt < $1.postedAt }
    }
    return nil
  }

  private var hasUnreadNotifications: Bool {
    notificationsViewModel.hasUnread(
      feedbackUnreadCount: feedbackViewModel.unreadCount,
      evaluationUnreadCount: evaluationSummaryViewModel?.unreadBadgeCount ?? 0
    )
  }

  // MARK: - Loading

  private func loadIfNeeded() async {
    // Each dependency retries independently. A `.task` cancelled mid-load
    // resets the in-flight VM to `.idle` (see Error.isTaskCancellation);
    // gating the whole reload on the week VM alone would strand any later VM
    // at `.idle` with no retry. Mirrors TrainingHistoryView.loadIfNeeded.
    // (StudentEvaluationSummaryViewModel has no `.idle` state, so it rides the
    // week VM's first-load.)
    if weekViewModel.state == .idle {
      await weekViewModel.load(studentID: studentID)
      await evaluationSummaryViewModel?.load(studentID: studentID)
    }
    if feedbackViewModel.state == .idle {
      await feedbackViewModel.load(studentID: studentID)
    }
    if notificationsViewModel.state == .idle {
      await notificationsViewModel.load(studentID: studentID)
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
    await feedbackViewModel.load(studentID: studentID)
    await evaluationSummaryViewModel?.load(studentID: studentID)
    await notificationsViewModel.load(studentID: studentID)
    await e1rmTrendViewModel.load(studentID: studentID)
    await profileMetricsViewModel.load(studentID: studentID)
  }

  private func openPlanNotification() {
    notificationsViewModel.markCurrentPlanSeen()
    onStartWorkout()
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
