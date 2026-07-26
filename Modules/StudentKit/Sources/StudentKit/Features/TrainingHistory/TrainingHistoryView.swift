// swiftlint:disable file_length type_body_length
import Analytics
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// Student 成长 (growth), reskinned to the design's single-scroll page: a fresh
/// PR banner, the three main-lift e1RM charts, the coach-feedback history, an
/// all-history stats row, and a button into the detailed week/set history. The
/// volume/intensity analytic is preserved as a supplementary section beneath.
@available(iOS 17.0, macOS 14.0, *)
public struct TrainingHistoryView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let onboarding: (any OnboardingProfileReading)?
  private let feedbackViewModel: FeedbackInboxViewModel?
  private let importedHistoryRefreshToken: Int
  private let onImportedHistoryRefresh: (@MainActor () async -> Void)?
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onOpenFeedbackNotification: () -> Void
  private let onOpenEvaluationNotification: () -> Void
  @State private var viewModel: TrainingHistoryViewModel
  @State private var trendViewModel: DashboardE1RMTrendViewModel
  @State private var prEvent: PRBreakthroughEvent?
  @State private var prFamily: LiftFamily?
  @State private var showsAllHistory = false
  @State private var currentOnboarding: OnboardingProfile?
  @State private var showsNotifications = false

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository,
    onboarding: (any OnboardingProfileReading)? = nil,
    feedbackViewModel: FeedbackInboxViewModel? = nil,
    importedHistoryRefreshToken: Int = 0,
    onImportedHistoryRefresh: (@MainActor () async -> Void)? = nil,
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {},
    onOpenFeedbackNotification: @escaping () -> Void = {},
    onOpenEvaluationNotification: @escaping () -> Void = {}
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.onboarding = onboarding
    self.feedbackViewModel = feedbackViewModel
    self.importedHistoryRefreshToken = importedHistoryRefreshToken
    self.onImportedHistoryRefresh = onImportedHistoryRefresh
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onOpenFeedbackNotification = onOpenFeedbackNotification
    self.onOpenEvaluationNotification = onOpenEvaluationNotification
    self._viewModel = State(initialValue: TrainingHistoryViewModel(plans: plans, logs: logs))
    self._trendViewModel = State(
      initialValue: DashboardE1RMTrendViewModel(
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding
      )
    )
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        HStack {
          Text("成长")
            .font(.MeetPR.display(size: 34, weight: .extraBold))
            .tracking(-0.7)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
          if let notifications {
            StudentNotificationBell(coordinator: notifications) {
              showsNotifications = true
            }
          }
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.space2)
        .meetPRRiseIn(index: 0)

        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
            if let prEvent { prBanner(prEvent) }

            switch viewModel.state {
            case .idle, .loading:
              ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
            case .error(let message):
              failureCard(message)
            case .loaded:
              liftCharts
                .meetPRRiseIn(index: 1)
              feedbackSection
                .meetPRRiseIn(index: 2)
              allHistorySection
                .meetPRRiseIn(index: 3)
              detailedHistoryButton
                .meetPRRiseIn(index: 4)
              volumeIntensitySection
                .meetPRRiseIn(index: 5)
            }
          }
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
          .padding(.vertical, MeetPRSpacing.point14)
        }
        .scrollContentBackground(.hidden)
        .refreshable {
          await onImportedHistoryRefresh?()
          await reloadAfterImportedHistoryChange()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(isPresented: $showsAllHistory) {
        AllHistoryScreen(viewModel: viewModel)
      }
      .modifier(
        OptionalStudentNotificationHostModifier(
          coordinator: notifications,
          showsNotifications: $showsNotifications,
          onOpenPlan: onOpenPlanNotification,
          onOpenFeedback: onOpenFeedbackNotification,
          onOpenEvaluation: onOpenEvaluationNotification
        )
      )
      .meetPRHideSystemTabBar()
    }
    .task {
      await loadIfNeeded()
      Analytics.shared.progressViewed(.e1rm)
      Analytics.shared.progressViewed(.volume)
    }
    .task(id: importedHistoryRefreshToken) {
      guard importedHistoryRefreshToken > 0 else { return }
      await reloadAfterImportedHistoryChange()
    }
  }

  // MARK: - PR banner

  private func prBanner(_ event: PRBreakthroughEvent) -> some View {
    HStack(spacing: MeetPRSpacing.point14) {
      Image(systemName: "trophy.fill")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size18))
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(width: 40, height: 40)
        .background(Color.MeetPR.gold500.opacity(0.15))
        .clipShape(Circle())
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text("新 e1RM PR · \(prWhen(event.occurredAt))")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.gold500)
        Text(
          "\(prFamily?.studentDisplayName ?? "三大项") e1RM 突破 "
            + "\(StudentFormatting.kilograms(event.breakthroughE1RMKg)) KG"
        )
        .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.goldSoft)
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
        Color.MeetPR.gold500.opacity(0.3), lineWidth: 1)
    }
  }

  private func prWhen(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return "今天" }
    return StudentFormatting.dayMonthFormatter.string(from: date)
  }

  // MARK: - e1RM lift charts

  private var liftCharts: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
      // 首屏黑话有解释 (P2-1): E1RM 是全 app 最高频的专业词,给一句白话锚点,
      // 别让新手对着首字母缩写猜。放段首出现一次,不逐卡重复。
      Text("E1RM = 用你完成的组数估算的单次最大重量")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
      ForEach(MainLiftExerciseFamilyResolver.dashboardFamilies, id: \.self) { family in
        liftChartCard(family)
      }
    }
  }

  private func liftChartCard(_ family: LiftFamily) -> some View {
    let row = trendRow(for: family)
    let now = Date()
    let displayPoint = row?.displayPoint(now: now)
    return VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
          Text("\(family.studentDisplayName) E1RM · \(chartPeriodLabel(for: row, now: now))")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.gold500)
          HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point6) {
            Text(displayPoint.map { StudentFormatting.kilograms($0.e1RMKg) } ?? "—")
              .font(.MeetPR.display(size: 38, weight: .extraBold).monospacedDigit())
              .foregroundStyle(Color.MeetPR.textPrimary)
            Text("KG")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size15, weight: .heavy))
              .foregroundStyle(Color.MeetPR.gold500)
          }
          .padding(.top, MeetPRSpacing.space1)
        }
        Spacer()
        if let row, let deltaKg = row.trendDeltaKg {
          let delta = deltaLabel(deltaKg)
          Text(delta.text)
            .font(.MeetPR.system(size: MeetPRFontMetrics.size13, design: .monospaced))
            .foregroundStyle(delta.color)
        }
      }
      if let row, !row.points.isEmpty || !row.rawEligiblePoints.isEmpty {
        e1rmChart(row)
          .padding(.top, MeetPRSpacing.space3)
      } else {
        Text("练几次就有趋势了")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
          .padding(.top, MeetPRSpacing.space3)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
    }
  }

  private func e1rmChart(_ row: DashboardE1RMTrendRow) -> some View {
    E1RMChart(
      smoothed: row.smoothedSamples.map { sample in
        E1RMChartPoint(
          id: sample.sampleID,
          date: sample.date,
          e1RMKg: sample.valueKg,
          origin: chartOrigin(sample.winnerOrigin),
          confidence: chartConfidence(sample.winnerConfidence),
          winnerPointID: sample.winnerPointID,
          marksRecord: sample.sampleID == sample.winnerPointID
        )
      },
      rawEligible: row.rawEligiblePoints.compactMap { point in
        guard point.confidence == .low else { return nil }
        return E1RMChartPoint(
          id: point.id,
          date: point.computedAt,
          e1RMKg: point.e1RMKg,
          origin: chartOrigin(point.origin),
          confidence: chartConfidence(point.confidence)
        )
      }
    )
    .frame(height: 140)
  }

  private func chartPeriodLabel(for row: DashboardE1RMTrendRow?, now: Date) -> String {
    row?.displaysHistoricalBest(now: now) == true
      ? "历史最佳" : "\(DashboardE1RMTrendViewModel.chartWindowDays) 天"
  }

  private func chartOrigin(_ origin: E1RMPointOrigin) -> E1RMChartPointOrigin {
    switch origin {
    case .logged: .logged
    case .imported: .imported
    }
  }

  private func chartConfidence(_ confidence: E1RMConfidence) -> E1RMChartPointConfidence {
    switch confidence {
    case .normal: .normal
    case .low: .low
    }
  }

  // MARK: - Coach feedback history

  @ViewBuilder
  private var feedbackSection: some View {
    if let items = feedbackItems, !items.isEmpty {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
        sectionLabel("教练反馈记录")
        VStack(spacing: MeetPRSpacing.zero) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 {
              Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1)
            }
            NavigationLink {
              FeedbackDetailView(item: item, viewModel: feedbackViewModel)
                .task { await feedbackViewModel?.markRead(item) }
            } label: {
              feedbackRow(item)
            }
            .buttonStyle(PressScaleButtonStyle())
          }
        }
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
            Color.MeetPR.borderDefault, lineWidth: 1)
        }
      }
    }
  }

  private func feedbackRow(_ item: CoachFeedback) -> some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.point10) {
      if item.readAt == nil {
        Circle().fill(Color.MeetPR.gold500).frame(width: 6, height: 6).padding(
          .top, MeetPRSpacing.point6)
      }
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(feedbackTitle(item))
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.textSecondary)
        Text(item.text)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Text(StudentFormatting.dayMonthFormatter.string(from: item.postedAt))
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .padding(MeetPRSpacing.point14)
  }

  private func feedbackTitle(_ item: CoachFeedback) -> String {
    let date = item.dayDate ?? item.postedAt
    var title = GrowthFormat.shortWeekday.string(from: date)
    if let dayDate = item.dayDate, let family = planFamily(on: dayDate) {
      title += " · \(family.studentDisplayName)"
    }
    return title
  }

  // MARK: - All-history stats

  private var allHistorySection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      sectionLabel("全部历史")
      HStack {
        stat("训练次数", value: sessionCountText)
        stat("训练周", value: "\(weekCount)")
        stat("三大项合计", value: sbdTotalText)
      }
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
          Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
  }

  private func stat(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
      Text(label).font(.MeetPR.system(size: MeetPRFontMetrics.size11)).foregroundStyle(
        Color.MeetPR.textTertiary)
      Text(value)
        .font(.MeetPR.display(size: 30, weight: .extraBold).monospacedDigit())
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Detailed history entry

  private var detailedHistoryButton: some View {
    Button {
      Analytics.shared.progressViewed(.history)
      showsAllHistory = true
    } label: {
      HStack(spacing: MeetPRSpacing.space3) {
        Image(systemName: "clock").font(.MeetPR.system(size: MeetPRFontMetrics.size20))
          .foregroundStyle(
            Color.MeetPR.textSecondary)
        VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
          Text("全部训练历史").font(.MeetPR.system(size: MeetPRFontMetrics.size15)).foregroundStyle(
            Color.MeetPR.textPrimary)
          Text("按周 / 月查看 · 含每组数据")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size12)).foregroundStyle(
              Color.MeetPR.textTertiary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.MeetPR.system(size: MeetPRFontMetrics.size14))
          .foregroundStyle(
            Color.MeetPR.textTertiary)
      }
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

  // MARK: - Volume / intensity (preserved analytic)

  @ViewBuilder
  private var volumeIntensitySection: some View {
    let buckets = ProgressMetrics.weeklyVolumeIntensity(from: loadedLogs)
    if !buckets.isEmpty {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
        sectionLabel("容量 / 强度")
        VolumeIntensityChart(buckets: buckets)
      }
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.textSecondary)
  }

  /// Repo-failure surface for the weeks/logs load (restores the old
  /// `.error` ContentUnavailableView behavior — never silently show 0 stats).
  private func failureCard(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Label("加载失败", systemImage: "exclamationmark.triangle")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.danger)
      Text(message)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        Task { await viewModel.load(studentID: studentID) }
      } label: {
        Text("重试")
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.gold500)
      }
      .buttonStyle(PressScaleButtonStyle())
      .padding(.top, MeetPRSpacing.space1)
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

  // MARK: - Derived data

  private var loadedWeeks: [TrainingHistoryViewModel.HistoryWeek] {
    if case .loaded(let weeks, _) = viewModel.state { return weeks }
    return []
  }

  private var loadedLogs: [StudentSetLog] {
    if case .loaded(_, let logs) = viewModel.state { return logs }
    return []
  }

  private var trendPresentation: DashboardE1RMTrendPresentation? {
    if case .loaded(let presentation) = trendViewModel.state { return presentation }
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

  private var feedbackItems: [CoachFeedback]? {
    guard let feedbackViewModel, case .loaded(let items) = feedbackViewModel.state else {
      return nil
    }
    return items.sorted { $0.postedAt > $1.postedAt }
  }

  /// Distinct calendar days on which at least one set was completed.
  private var sessionCountText: String {
    "\(Self.completedSessionCount(logs: loadedLogs, calendar: .current))"
  }

  static func completedSessionCount(
    logs: [StudentSetLog],
    calendar: Calendar
  ) -> Int {
    Set(
      logs.filter { $0.completed && !$0.assumed }
        .map { calendar.startOfDay(for: $0.loggedAt) }
    ).count
  }

  private var weekCount: Int { loadedWeeks.count }

  /// SBD e1RM total — sum of the latest squat / bench / deadlift e1RM. Shown
  /// only when all three lifts have data (a partial sum would misrepresent a
  /// "total"). Replaces a fabricated PR count — the repo exposes no total-PR API.
  private var sbdTotalText: String {
    guard let rows = trendPresentation?.rows else { return "—" }
    let values = MainLiftExerciseFamilyResolver.dashboardFamilies.compactMap { family in
      rows.first { $0.family == family }?.displayPoint(now: Date())?.e1RMKg
    }
    guard values.count == 3 else { return "—" }
    return StudentFormatting.kilograms(values.reduce(0, +))
  }

  private func planFamily(on date: Date) -> LiftFamily? {
    for week in loadedWeeks {
      if let day = week.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
        return day.exercises.compactMap {
          resolveCompetitionFamily(exercise: $0.exercise, onboarding: currentOnboarding)
        }.first
      }
    }
    return nil
  }

  private func familyForExercise(_ exerciseId: UUID) -> LiftFamily? {
    for week in loadedWeeks {
      for day in week.days {
        for slot in day.exercises where slot.exercise.id == exerciseId {
          return resolveCompetitionFamily(
            exercise: slot.exercise,
            onboarding: currentOnboarding
          )
        }
      }
    }
    return nil
  }

  // MARK: - Loading

  private func loadIfNeeded() async {
    currentOnboarding = try? await onboarding?.fetchProfile(studentId: studentID)
    if viewModel.state == .idle {
      await viewModel.load(studentID: studentID)
    }
    if trendViewModel.state == .idle {
      await trendViewModel.load(studentID: studentID)
    }
    if let feedbackViewModel, feedbackViewModel.state == .idle {
      await feedbackViewModel.load(studentID: studentID)
    }
    let prs = (try? await e1rm.unacknowledgedPRs(studentId: studentID)) ?? []
    prEvent = prs.max { $0.occurredAt < $1.occurredAt }
    prFamily = prEvent.flatMap { familyForExercise($0.exerciseId) }
  }

  private func reloadAfterImportedHistoryChange() async {
    currentOnboarding = try? await onboarding?.fetchProfile(studentId: studentID)
    await viewModel.load(studentID: studentID)
    await trendViewModel.load(studentID: studentID)
    let prs = (try? await e1rm.unacknowledgedPRs(studentId: studentID)) ?? []
    prEvent = prs.max { $0.occurredAt < $1.occurredAt }
    prFamily = prEvent.flatMap { familyForExercise($0.exerciseId) }
  }
}

/// The pushed "detailed history" screen — owns the exercise-filter selection and
/// wraps the existing week/set `HistoryEntriesView`.
@available(iOS 17.0, macOS 14.0, *)
private struct AllHistoryScreen: View {
  let viewModel: TrainingHistoryViewModel
  @State private var selectedExerciseName: String?

  var body: some View {
    Group {
      if case .loaded(let weeks, let logs) = viewModel.state {
        HistoryEntriesView(weeks: weeks, logs: logs, selectedExerciseName: $selectedExerciseName)
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .navigationTitle("训练历史")
  }
}

private enum GrowthFormat {
  static let shortWeekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter
  }()
}
// swiftlint:enable file_length type_body_length
