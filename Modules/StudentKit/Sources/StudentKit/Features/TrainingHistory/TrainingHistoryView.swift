// swiftlint:disable file_length type_body_length
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
  private let feedbackViewModel: FeedbackInboxViewModel?
  private let trainingMode: TrainingMode
  private let importedHistoryRefreshToken: Int
  private let onImportedHistoryRefresh: (@MainActor () async -> Void)?
  @State private var viewModel: TrainingHistoryViewModel
  @State private var trendViewModel: DashboardE1RMTrendViewModel
  @State private var prEvent: PRBreakthroughEvent?
  @State private var prFamily: LiftFamily?
  @State private var pendingPRs: [PRBreakthroughEvent] = []
  @State private var showsAllHistory = false

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository,
    onboarding: any OnboardingProfileReading,
    feedbackViewModel: FeedbackInboxViewModel? = nil,
    sessionReviews: (any SessionReviewRepository)? = nil,
    trainingMode: TrainingMode = .coached,
    soloCatalog: [Exercise] = [],
    importedHistoryRefreshToken: Int = 0,
    onImportedHistoryRefresh: (@MainActor () async -> Void)? = nil
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.feedbackViewModel = feedbackViewModel
    self.trainingMode = trainingMode
    self.importedHistoryRefreshToken = importedHistoryRefreshToken
    self.onImportedHistoryRefresh = onImportedHistoryRefresh
    self._viewModel = State(
      initialValue: TrainingHistoryViewModel(
        plans: plans, logs: logs, onboarding: onboarding,
        reviews: sessionReviews, e1rm: e1rm, mode: trainingMode, catalog: soloCatalog))
    self._trendViewModel = State(
      initialValue: DashboardE1RMTrendViewModel(
        plans: plans, e1rm: e1rm, onboarding: onboarding,
        mode: trainingMode, catalog: soloCatalog)
    )
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack {
          Text("成长")
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            if let prEvent { prBanner(prEvent) }
            if !pendingPRs.isEmpty { unacknowledgedPRSection }

            switch viewModel.state {
            case .idle, .loading:
              ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
            case .error(let message):
              failureCard(message)
            case .loaded:
              liftCharts
              feedbackSection
              allHistorySection
              detailedHistoryButton
              volumeIntensitySection
            }
          }
          .padding(16)
        }
        .scrollContentBackground(.hidden)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .hideNavigationBar()
      .navigationDestination(isPresented: $showsAllHistory) {
        AllHistoryScreen(viewModel: viewModel, mode: trainingMode)
      }
    }
    .task { await loadIfNeeded() }
    .task(id: importedHistoryRefreshToken) {
      guard importedHistoryRefreshToken > 0 else { return }
      await reloadAfterImportedHistoryChange()
    }
    .refreshable {
      await onImportedHistoryRefresh?()
      await reloadAfterImportedHistoryChange()
    }
  }

  // MARK: - PR banner

  private func prBanner(_ event: PRBreakthroughEvent) -> some View {
    HStack(spacing: 14) {
      Image(systemName: "trophy.fill")
        .font(.system(size: 18))
        .foregroundStyle(Color.MeetPR.brandRed)
        .frame(width: 40, height: 40)
        .background(Color.MeetPR.brandRed.opacity(0.15))
        .clipShape(Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text("新 e1RM PR · \(prWhen(event.occurredAt))")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.brandRed)
        Text(
          "\(prFamily?.studentDisplayName ?? "三大项") e1RM 突破 "
            + "\(StudentFormatting.kilograms(event.breakthroughE1RMKg)) KG"
        )
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.MeetPR.brandRedSoft)
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.brandRed.opacity(0.3), lineWidth: 1)
    }
  }

  private func prWhen(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return "今天" }
    return StudentFormatting.dayMonthFormatter.string(from: date)
  }

  // MARK: - e1RM lift charts

  private var liftCharts: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 首屏黑话有解释 (P2-1): E1RM 是全 app 最高频的专业词,给一句白话锚点,
      // 别让新手对着首字母缩写猜。放段首出现一次,不逐卡重复。
      Text("E1RM = 用你完成的组数估算的单次最大重量,越高越强")
        .font(.system(size: 12))
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
      ForEach(MainLiftExerciseFamilyResolver.dashboardFamilies, id: \.self) { family in
        liftChartCard(family)
      }
    }
  }

  private func liftChartCard(_ family: LiftFamily) -> some View {
    let row = trendRow(for: family)
    let displayPoint = row?.displayPoint()
    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 0) {
          Text("\(family.studentDisplayName) E1RM · \(chartPeriodLabel(for: row))")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
          HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(displayPoint.map { StudentFormatting.kilograms($0.e1RMKg) } ?? "—")
              .font(.system(size: 40, weight: .heavy).monospacedDigit())
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text("KG")
              .font(.system(size: 15, weight: .heavy))
              .foregroundStyle(Color.MeetPR.brandRed)
          }
          .padding(.top, 4)
        }
        Spacer()
        if let row, let deltaKg = row.trendDeltaKg {
          let delta = deltaLabel(deltaKg)
          Text(delta.text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(delta.color)
        }
      }
      if let row, !row.points.isEmpty {
        sparklineWithAxis(row)
          .padding(.top, 12)
      } else {
        Text("练几次就有趋势了")
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
          .padding(.top, 12)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  /// e1RM sparkline with a min/max kg anchor on the left (P2-8: 无轴无点标).
  /// The kg values live here, not inside the normalized Sparkline — max maps
  /// to the top of the plot (y=5) and min to the bottom (y=85), matching
  /// `sparklinePoints(top: 5, usableHeight: 80)`.
  private func sparklineWithAxis(_ row: DashboardE1RMTrendRow) -> some View {
    let values = row.points.map(\.e1RMKg)
    let maxKg = values.max() ?? 0
    let minKg = values.min() ?? 0
    return HStack(alignment: .center, spacing: 8) {
      VStack(alignment: .trailing, spacing: 0) {
        axisLabel(maxKg)
        Spacer(minLength: 0)
        if maxKg != minKg { axisLabel(minKg) }
      }
      .frame(height: 90)
      Sparkline(
        points: row.sparklinePoints(top: 5, usableHeight: 80),
        viewBox: CGSize(width: 600, height: 90),
        showsPointDots: true
      )
      .frame(height: 90)
    }
  }

  private func axisLabel(_ kilograms: Double) -> some View {
    Text(StudentFormatting.kilograms(kilograms))
      .font(.system(size: 10, design: .monospaced))
      .foregroundStyle(Color.MeetPR.fgTertiary)
  }

  private func chartPeriodLabel(for row: DashboardE1RMTrendRow?) -> String {
    row?.displaysHistoricalBest() == true ? "历史最佳" : "90 天"
  }

  // MARK: - Coach feedback history

  @ViewBuilder
  private var feedbackSection: some View {
    if let items = feedbackItems, !items.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        sectionLabel("教练反馈记录")
        VStack(spacing: 0) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 {
              Rectangle().fill(Color.MeetPR.border).frame(height: 1)
            }
            NavigationLink {
              FeedbackDetailView(item: item)
                .task { await feedbackViewModel?.markRead(item) }
            } label: {
              feedbackRow(item)
            }
            .buttonStyle(.plain)
          }
        }
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
      }
    }
  }

  private func feedbackRow(_ item: CoachFeedback) -> some View {
    HStack(alignment: .top, spacing: 10) {
      if item.readAt == nil {
        Circle().fill(Color.MeetPR.brandRed).frame(width: 6, height: 6).padding(.top, 6)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(feedbackTitle(item))
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Text(item.text)
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Text(StudentFormatting.dayMonthFormatter.string(from: item.postedAt))
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
    .padding(14)
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
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("全部历史")
      HStack {
        stat("训练次数", value: sessionCountText)
        if trainingMode == .selfTrain {
          // 没有计划周的概念 (spec 047 §2) — 自然历月替代。
          stat("本月次数", value: "\(viewModel.currentMonthSessionCount)")
        } else {
          stat("训练周", value: "\(weekCount)")
        }
        stat("三大项合计", value: sbdTotalText)
      }
      .padding(16)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
    }
  }

  private func stat(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).font(.system(size: 11)).foregroundStyle(Color.MeetPR.fgTertiary)
      Text(value)
        .font(.system(size: 28, weight: .heavy).monospacedDigit())
        .foregroundStyle(Color.MeetPR.fgPrimary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Detailed history entry

  private var detailedHistoryButton: some View {
    Button {
      showsAllHistory = true
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "clock").font(.system(size: 20)).foregroundStyle(Color.MeetPR.fgSecondary)
        VStack(alignment: .leading, spacing: 2) {
          Text("全部训练历史").font(.system(size: 15)).foregroundStyle(Color.MeetPR.fgPrimary)
          Text("按周 / 月查看 · 含每组数据")
            .font(.system(size: 12)).foregroundStyle(Color.MeetPR.fgTertiary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(
          Color.MeetPR.fgTertiary)
      }
      .padding(16)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Volume / intensity (preserved analytic)

  @ViewBuilder
  private var volumeIntensitySection: some View {
    let buckets = ProgressMetrics.weeklyVolumeIntensity(from: loadedLogs)
    if !buckets.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        sectionLabel("容量 / 强度")
        VolumeIntensityChart(buckets: buckets)
      }
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.fgSecondary)
  }

  /// Repo-failure surface for the weeks/logs load (restores the old
  /// `.error` ContentUnavailableView behavior — never silently show 0 stats).
  private func failureCard(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("加载失败", systemImage: "exclamationmark.triangle")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.amber)
      Text(message)
        .font(.system(size: 14))
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        Task { await viewModel.load(studentID: studentID) }
      } label: {
        Text("重试")
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.brandRed)
      }
      .buttonStyle(.plain)
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
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
      ? Color.MeetPR.green : (kilograms < 0 ? Color.MeetPR.brandRed : Color.MeetPR.fgSecondary)
    return ("\(sign)\(StudentFormatting.kilograms(abs(kilograms))) KG", color)
  }

  private var feedbackItems: [CoachFeedback]? {
    // 成长 tab 反馈段仅 coached (spec 047 AC#3 solo 零教练字样): a solo account
    // structurally has no coach in V1, so 「教练反馈记录」 must never render —
    // gate at the source so it can't leak even if a feedbackViewModel is injected.
    guard Self.showsCoachFeedback(trainingMode: trainingMode) else { return nil }
    guard let feedbackViewModel, case .loaded(let items) = feedbackViewModel.state else {
      return nil
    }
    return items.sorted { $0.postedAt > $1.postedAt }
  }

  static func showsCoachFeedback(trainingMode: TrainingMode) -> Bool {
    trainingMode == .coached
  }

  /// Distinct calendar days on which at least one set was completed.
  private var sessionCountText: String {
    "\(Self.completedSessionCount(logs: loadedLogs))"
  }

  static func completedSessionCount(
    logs: [StudentSetLog],
    calendar: Calendar = .current
  ) -> Int {
    Set(
      logs.filter { $0.completed && !$0.assumed }
        .map { calendar.startOfDay(for: $0.loggedAt) }
    )
    .count
  }

  private var weekCount: Int { loadedWeeks.count }

  /// SBD e1RM total — sum of the latest squat / bench / deadlift e1RM. Shown
  /// only when all three lifts have data (a partial sum would misrepresent a
  /// "total"). Replaces a fabricated PR count — the repo exposes no total-PR API.
  private var sbdTotalText: String {
    guard let rows = trendPresentation?.rows else { return "—" }
    let values = MainLiftExerciseFamilyResolver.dashboardFamilies.compactMap { family in
      rows.first { $0.family == family }?.displayPoint()?.e1RMKg
    }
    guard values.count == 3 else { return "—" }
    return StudentFormatting.kilograms(values.reduce(0, +))
  }

  private func planFamily(on date: Date) -> LiftFamily? {
    for week in loadedWeeks {
      if let day = week.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
        return day.exercises.first {
          $0.exercise.exerciseType == .mainLift && $0.exercise.mainLiftFamily != nil
        }?.exercise.mainLiftFamily
      }
    }
    return nil
  }

  private func familyForExercise(_ exerciseId: UUID) -> LiftFamily? {
    for week in loadedWeeks {
      for day in week.days {
        for slot in day.exercises where slot.exercise.id == exerciseId {
          return slot.exercise.mainLiftFamily
        }
      }
    }
    return nil
  }

  // MARK: - Loading

  private func loadIfNeeded() async {
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
    pendingPRs = prs.sorted { $0.occurredAt > $1.occurredAt }
    prEvent = pendingPRs.first
    prFamily = prEvent.flatMap { familyForExercise($0.exerciseId) }
  }

  private func reloadAfterImportedHistoryChange() async {
    await viewModel.load(studentID: studentID)
    await trendViewModel.load(studentID: studentID)
    let prs = (try? await e1rm.unacknowledgedPRs(studentId: studentID)) ?? []
    pendingPRs = prs.sorted { $0.occurredAt > $1.occurredAt }
    prEvent = pendingPRs.first
    prFamily = prEvent.flatMap { familyForExercise($0.exerciseId) }
  }

  /// 红点终于有地方消费 (spec 051 §2): acknowledging removes the row, the
  /// banner, and (via the tab-switch recount) the profile badge.
  private func acknowledge(_ event: PRBreakthroughEvent) async {
    try? await e1rm.acknowledgePR(eventId: event.id)
    pendingPRs.removeAll { $0.id == event.id }
    prEvent = pendingPRs.first
    prFamily = prEvent.flatMap { familyForExercise($0.exerciseId) }
  }

  private var unacknowledgedPRSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("未确认 PR")
        .font(.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      ForEach(pendingPRs, id: \.id) { event in
        HStack(spacing: 10) {
          Text("🎉")
          VStack(alignment: .leading, spacing: 2) {
            Text(prRowTitle(event))
              .font(.subheadline.bold())
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text(StudentFormatting.dayMonthFormatter.string(from: event.occurredAt))
              .font(.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
          Spacer()
          Button("确认") {
            Task { await acknowledge(event) }
          }
          .font(.footnote.bold())
          .buttonStyle(.bordered)
          .accessibilityIdentifier("growth.pr.ack.\(event.id.uuidString)")
        }
        .padding(12)
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: 10))
      }
    }
  }

  private func prRowTitle(_ event: PRBreakthroughEvent) -> String {
    let value = StudentFormatting.kilograms(event.breakthroughE1RMKg)
    if let family = familyForExercise(event.exerciseId) {
      return "\(family.studentDisplayName) e1RM 突破 · \(value) kg"
    }
    return "e1RM 突破 · \(value) kg"
  }
}

/// The pushed "detailed history" screen — owns the exercise-filter selection and
/// wraps the existing week/set `HistoryEntriesView`.
@available(iOS 17.0, macOS 14.0, *)
private struct AllHistoryScreen: View {
  let viewModel: TrainingHistoryViewModel
  var mode: TrainingMode = .coached
  @State private var selectedExerciseName: String?

  var body: some View {
    Group {
      if case .loaded(let weeks, let logs) = viewModel.state {
        if mode == .selfTrain {
          // 无计划周可分组 (spec 047 §2) — 月分组日卡片替代。
          SoloHistoryListView(months: viewModel.soloMonths, reviews: viewModel.reviewsByDay)
        } else {
          HistoryEntriesView(
            weeks: weeks, logs: logs, reviews: viewModel.reviewsByDay,
            selectedExerciseName: $selectedExerciseName)
        }
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
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
