// swiftlint:disable file_length
import Analytics
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// Black-gold v3 成长 tab. The view owns presentation and navigation only;
/// plans, logs, e1RM, onboarding, and feedback continue through their existing
/// repositories and view models.
@available(iOS 17.0, macOS 14.0, *)
public struct TrainingHistoryView: View {
  private let studentID: UUID
  private let onboarding: (any OnboardingProfileReading)?
  private let feedbackViewModel: FeedbackInboxViewModel?
  private let importedHistoryRefreshToken: Int
  private let onImportedHistoryRefresh: (@MainActor () async -> Void)?
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onOpenFeedbackNotification: () -> Void
  private let onOpenEvaluationNotification: () -> Void

  @State private var viewModel: TrainingHistoryViewModel
  @State private var growthViewModel: GrowthCurveViewModel
  @State private var currentOnboarding: OnboardingProfile?
  @State private var ranges: [LiftFamily: GrowthTimeRange] = [:]
  @State private var snapshots: [LiftFamily: GrowthCurveSnapshot] = [:]
  @State private var showsAllHistory = false
  @State private var showsNotifications = false
  @State private var conversationID: UUID?

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
    self.onboarding = onboarding
    self.feedbackViewModel = feedbackViewModel
    self.importedHistoryRefreshToken = importedHistoryRefreshToken
    self.onImportedHistoryRefresh = onImportedHistoryRefresh
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onOpenFeedbackNotification = onOpenFeedbackNotification
    self.onOpenEvaluationNotification = onOpenEvaluationNotification
    self._viewModel = State(initialValue: TrainingHistoryViewModel(plans: plans, logs: logs))
    self._growthViewModel = State(
      initialValue: GrowthCurveViewModel(
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding
      )
    )
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          GrowthScreenHeader()
          content
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.point6)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollIndicators(.hidden)
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(isPresented: $showsAllHistory) {
        AllHistoryScreen(viewModel: viewModel)
      }
      .modifier(
        OptionalStudentNotificationHostModifier(
          coordinator: notifications,
          showsNotifications: $showsNotifications,
          conversationID: $conversationID,
          onOpenPlan: onOpenPlanNotification,
          onOpenFeedback: onOpenFeedbackNotification,
          onOpenEvaluation: onOpenEvaluationNotification
        )
      )
      .refreshable {
        await onImportedHistoryRefresh?()
        await reload()
      }
    }
    .background(Color.MeetPR.bgBase)
    .task {
      await loadIfNeeded()
      Analytics.shared.progressViewed(.e1rm)
      Analytics.shared.progressViewed(.volume)
    }
    .task(id: importedHistoryRefreshToken) {
      guard importedHistoryRefreshToken > 0 else { return }
      await reload()
    }
  }

  @ViewBuilder
  private var content: some View {
    switch (viewModel.state, growthViewModel.state) {
    case (.error(let message), _), (_, .error(let message)):
      GrowthFailureCard(message: message) {
        Task { await reload() }
      }
    case (.loaded, .loaded):
      loadedContent
    default:
      GrowthScreenSkeleton()
    }
  }

  private var loadedContent: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      ForEach(MainLiftExerciseFamilyResolver.dashboardFamilies, id: \.self) { family in
        GrowthE1RMCard(
          snapshot: snapshot(for: family),
          range: range(for: family),
          onCycleRange: { cycleRange(for: family) }
        )
      }

      GrowthSectionLabel("E1RM vs 训练 1RM")
        .padding(.top, MeetPRSpacing.space2)
      GrowthComparisonCard(presentation: comparison)

      GrowthSectionLabel("教练反馈记录")
        .padding(.top, MeetPRSpacing.space2)
      feedbackEntry

      GrowthSectionLabel("全部历史")
        .padding(.top, MeetPRSpacing.space2)
      GrowthHistoryStatsCard(stats: stats)

      Button {
        Analytics.shared.progressViewed(.history)
        showsAllHistory = true
      } label: {
        GrowthNavigationCard(
          icon: "clock",
          title: "全部训练历史",
          subtitle: "按周 / 月查看 · 含每组数据"
        )
      }
      .buttonStyle(.plain)
      .accessibilityHint("打开训练历史列表")

      GrowthSectionLabel("容量 / 强度")
        .padding(.top, MeetPRSpacing.space2)
      VolumeIntensityChart(
        buckets: chartBuckets,
        isUnlocked: stats.unlocksTrends
      )
    }
  }

  @ViewBuilder
  private var feedbackEntry: some View {
    if let feedbackViewModel {
      NavigationLink {
        FeedbackInboxView(studentID: studentID, viewModel: feedbackViewModel)
      } label: {
        GrowthNavigationCard(
          icon: "bubble.left",
          title: "全部教练反馈",
          subtitle: "共 \(feedbackCount) 条 · 含视频回放"
        )
      }
      .buttonStyle(.plain)
    } else {
      GrowthNavigationCard(
        icon: "bubble.left",
        title: "全部教练反馈",
        subtitle: "暂无反馈数据"
      )
    }
  }

  private var comparison: GrowthComparisonPresentation {
    GrowthComparisonPresentation.make(
      snapshots: MainLiftExerciseFamilyResolver.dashboardFamilies.map(snapshot(for:)),
      onboarding: currentOnboarding
    )
  }

  private var stats: GrowthHistoryStats {
    GrowthScreenPresentation.historyStats(logs: loadedLogs)
  }

  private var chartBuckets: [WeeklyProgressMetric] {
    GrowthScreenPresentation.chartBuckets(logs: loadedLogs)
  }

  private var loadedLogs: [StudentSetLog] {
    guard case .loaded(_, let logs) = viewModel.state else { return [] }
    return logs
  }

  private var feedbackCount: Int {
    guard let feedbackViewModel, case .loaded(let items) = feedbackViewModel.state else {
      return 0
    }
    return items.count
  }

  private func snapshot(for family: LiftFamily) -> GrowthCurveSnapshot {
    snapshots[family] ?? .empty(family: family)
  }

  private func range(for family: LiftFamily) -> GrowthTimeRange {
    ranges[family] ?? .ninetyDays
  }

  private func cycleRange(for family: LiftFamily) {
    let all = GrowthTimeRange.allCases
    let current = range(for: family)
    let currentIndex = all.firstIndex(of: current) ?? 0
    ranges[family] = all[(currentIndex + 1) % all.count]
    refreshSnapshot(for: family)
  }

  private func loadIfNeeded() async {
    currentOnboarding = try? await onboarding?.fetchProfile(studentId: studentID)
    if viewModel.state == .idle {
      await viewModel.load(studentID: studentID)
    }
    if growthViewModel.state == .idle {
      await growthViewModel.load(studentID: studentID)
    }
    adoptInitialRangesIfNeeded()
    refreshSnapshots()
    if let feedbackViewModel, feedbackViewModel.state == .idle {
      await feedbackViewModel.load(studentID: studentID)
    }
  }

  private func reload() async {
    currentOnboarding = try? await onboarding?.fetchProfile(studentId: studentID)
    await viewModel.load(studentID: studentID)
    await growthViewModel.load(studentID: studentID)
    adoptInitialRangesIfNeeded()
    refreshSnapshots()
    if let feedbackViewModel {
      await feedbackViewModel.load(studentID: studentID)
    }
  }

  static func completedSessionCount(
    logs: [StudentSetLog],
    calendar: Calendar
  ) -> Int {
    GrowthScreenPresentation.historyStats(logs: logs, calendar: calendar)
      .trainingSessionCount
  }

  private func refreshSnapshots() {
    for family in MainLiftExerciseFamilyResolver.dashboardFamilies {
      refreshSnapshot(for: family)
    }
  }

  private func adoptInitialRangesIfNeeded() {
    guard ranges.isEmpty, growthViewModel.state == .loaded else { return }
    let initialRange = GrowthTimeRange(timeWindow: growthViewModel.selectedWindow)
    for family in MainLiftExerciseFamilyResolver.dashboardFamilies {
      ranges[family] = initialRange
    }
  }

  private func refreshSnapshot(for family: LiftFamily) {
    snapshots[family] = GrowthScreenPresentation.snapshot(
      from: growthViewModel,
      family: family,
      range: range(for: family)
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthScreenHeader: View {
  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      MeetPRMark(size: 44)
        .frame(width: 92, height: MeetPRFontMetrics.size16, alignment: .leading)
        .clipped()
      Text("成长")
        .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("E1RM ＝ 用你完成的组数估算的单次最大重量")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textFaint)
        .padding(.top, -MeetPRSpacing.space2)
    }
    .accessibilityElement(children: .combine)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthSectionLabel: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
      .foregroundStyle(Color.MeetPR.textSecondary)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthComparisonCard: View {
  let presentation: GrowthComparisonPresentation

  var body: some View {
    VStack(spacing: MeetPRSpacing.point15) {
      HStack(alignment: .bottom) {
        total(
          title: "三项 E1RM 合计",
          value: presentation.estimatedTotalKg.map(Self.weight) ?? "—",
          color: Color.MeetPR.textPrimary,
          alignment: .leading
        )
        Rectangle()
          .fill(Color.MeetPR.borderStrong)
          .frame(width: 1, height: MeetPRSpacing.point34)
        total(
          title: "训练 1RM 合计",
          value: presentation.trainingTotalKg.map(Self.weight) ?? "—",
          color: Color.MeetPR.textMuted,
          alignment: .trailing
        )
      }

      ForEach(presentation.rows) { row in
        VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
          HStack {
            Text(row.family.studentDisplayName)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Spacer()
            Text(rowValue(row))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(Color.MeetPR.bgInset)
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [Color.MeetPR.goldBarDeep, Color.MeetPR.gold500],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .frame(width: proxy.size.width * row.progress)
            }
          }
          .frame(height: MeetPRSpacing.space2)
          if row.hasExceededTrainingBaseline, let percentage = row.percentage {
            Label("已突破训练 1RM · \(percentage)%", systemImage: "checkmark")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
              .foregroundStyle(Color.MeetPR.success)
          }
        }
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private func total(
    title: String,
    value: String,
    color: Color,
    alignment: HorizontalAlignment
  ) -> some View {
    VStack(alignment: alignment, spacing: MeetPRSpacing.point3) {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point3) {
        Text(value)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size28, weight: .bold))
        Text("kg")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
  }

  private func rowValue(_ row: GrowthComparisonRow) -> String {
    let estimated = row.estimatedOneRepMaxKg.map(Self.weight) ?? "—"
    let training = row.trainingOneRepMaxKg.map(Self.weight) ?? "—"
    return "\(estimated) / \(training) kg"
  }

  private static func weight(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
  }

  private static func weight(_ value: Decimal) -> String {
    UnitDisplay.plainString(value)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthHistoryStatsCard: View {
  let stats: GrowthHistoryStats

  var body: some View {
    HStack {
      stat("训练次数", stats.trainingSessionCount.formatted())
      stat("训练周", stats.trainingWeekCount.formatted())
      stat(
        "训练总容量",
        NSDecimalNumber(decimal: stats.totalVolumeKg).doubleValue.formatted(
          .number.grouping(.automatic).precision(.fractionLength(0))
        ),
        unit: "kg"
      )
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private func stat(_ label: String, _ value: String, unit: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text(label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point2) {
        Text(value)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size30, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .minimumScaleFactor(0.65)
          .lineLimit(1)
        if let unit {
          Text(unit)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthNavigationCard: View {
  let icon: String
  let title: String
  let subtitle: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Image(systemName: icon)
        .font(.system(size: MeetPRFontMetrics.size19, weight: .medium))
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(width: 40, height: 40)
        .background(Color.MeetPR.surfaceRaised)
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(subtitle)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.system(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDim)
    }
    .padding(.vertical, MeetPRSpacing.point14)
    .padding(.horizontal, MeetPRSpacing.point15)
    .frame(minHeight: 68)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .contentShape(Rectangle())
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthScreenSkeleton: View {
  var body: some View {
    VStack(spacing: MeetPRSpacing.point14) {
      ForEach(0..<3, id: \.self) { _ in
        RoundedRectangle(cornerRadius: MeetPRRadius.card)
          .fill(Color.MeetPR.textGhost.opacity(0.3))
          .frame(height: 220)
      }
    }
    .accessibilityLabel("正在加载成长数据")
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthFailureCard: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Label("加载失败", systemImage: "exclamationmark.triangle")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
        .foregroundStyle(Color.MeetPR.dangerMuted)
      Text(message)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Button("重试", action: retry)
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

/// Existing detailed week/set history retained behind the v3 entry card.
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
// swiftlint:enable file_length
