import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// Student home, modeled on Juggernaut/MSB dashboards: today's workout entry,
/// a this-week progress strip, and the latest coach feedback. Composes the
/// existing week + feedback view models — no new persistence.
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
        VStack(alignment: .leading, spacing: 24) {
          if let evaluationSummaryViewModel {
            EvaluationCompletedCard(viewModel: evaluationSummaryViewModel)
          }

          TodayWorkoutCard(today: today, logs: weekData?.logs ?? [], onStart: onStartWorkout)

          if let data = weekData, !data.days.isEmpty {
            DashboardSection(title: "本周") {
              WeekStrip(days: data.days, logs: data.logs)
            }
          }

          NavigationLink(
            destination: GrowthCurveView(studentID: studentID, plans: plans, e1rm: e1rm),
            label: { E1RMMiniTrendCard(state: e1rmTrendViewModel.state) }
          )
          .buttonStyle(.plain)

          if let metrics = profileMetricsViewModel.metrics {
            DashboardProfileMetricsView(metrics: metrics)
          }

          DashboardSection(title: "教练反馈", action: ("查看全部", onSeeAllFeedback)) {
            RecentFeedback(viewModel: feedbackViewModel)
          }
        }
        .padding()
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
      .navigationTitle("仪表盘")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          notificationButton
        }
      }
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
  }

  private var notificationButton: some View {
    Button(
      action: { showsNotifications = true },
      label: {
        ZStack(alignment: .topTrailing) {
          Image(systemName: hasUnreadNotifications ? "bell.badge" : "bell")
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

  private var hasUnreadNotifications: Bool {
    notificationsViewModel.hasUnread(
      feedbackUnreadCount: feedbackViewModel.unreadCount,
      evaluationUnreadCount: evaluationSummaryViewModel?.unreadBadgeCount ?? 0
    )
  }

  private func loadIfNeeded() async {
    if weekViewModel.state == .idle {
      await reload()
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

  private var weekData: (days: [StudentPlanDay], logs: [StudentSetLog])? {
    if case .loaded(let days, let logs, _) = weekViewModel.state {
      return (days, logs)
    }
    return nil
  }

  private var today: StudentPlanDay? {
    weekData?.days.first { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TodayWorkoutCard: View {
  let today: StudentPlanDay?
  let logs: [StudentSetLog]
  let onStart: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(
        StudentFormatting.weekdayFormatter.string(from: Date()) + " · "
          + StudentFormatting.dayMonthFormatter.string(from: Date())
      )
      .font(.subheadline)
      .foregroundStyle(Color.MeetPR.fgSecondary)

      if let today, !today.exercises.isEmpty {
        let progress = StudentFormatting.completedCount(for: today, logs: logs)
        VStack(alignment: .leading, spacing: 12) {
          Text("今日训练")
            .font(.title2.bold())
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("\(today.exercises.count) 个动作 · \(progress.completed)/\(progress.total) 组完成")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color.MeetPR.fgSecondary)
          Button(action: onStart) {
            Text(progress.completed == 0 ? "开始训练" : "继续训练")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.MeetPR.brandRed)
              .clipShape(.rect(cornerRadius: 12))
          }
          .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(DashboardCard())
      } else {
        HStack(spacing: 10) {
          Image(systemName: "bed.double.fill")
            .foregroundStyle(Color.MeetPR.fgSecondary)
          Text("今日休息")
            .font(.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(DashboardCard())
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct WeekStrip: View {
  let days: [StudentPlanDay]
  let logs: [StudentSetLog]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(days) { day in
          NavigationLink {
            DayDetailView(day: day, logs: logs)
          } label: {
            DayChip(day: day, logs: logs)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DayChip: View {
  let day: StudentPlanDay
  let logs: [StudentSetLog]

  var body: some View {
    let isToday = Calendar.current.isDate(day.date, inSameDayAs: Date())
    let progress = TrainingDayProgress(day: day, logs: logs)

    VStack(spacing: 6) {
      Text(Self.shortWeekday.string(from: day.date))
        .font(.caption2)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Text(Self.dayNumber.string(from: day.date))
        .font(.headline.monospacedDigit())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Circle()
        .fill(progress.state.dotColor)
        .frame(width: 7, height: 7)
    }
    .frame(width: 52)
    .padding(.vertical, 12)
    .background(isToday ? Color.MeetPR.surface3 : Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(isToday ? Color.MeetPR.green : Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
  }

  private static let shortWeekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter
  }()

  private static let dayNumber: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.setLocalizedDateFormatFromTemplate("d")
    return formatter
  }()
}

@available(iOS 17.0, macOS 14.0, *)
private struct RecentFeedback: View {
  let viewModel: FeedbackInboxViewModel

  var body: some View {
    if case .loaded(let items) = viewModel.state, !items.isEmpty {
      VStack(spacing: 12) {
        ForEach(items.prefix(2)) { item in
          NavigationLink {
            FeedbackDetailView(item: item)
              .task { await viewModel.markRead(item) }
          } label: {
            FeedbackRowCard(item: item)
          }
          .buttonStyle(.plain)
        }
      }
    } else {
      Text("暂无反馈")
        .font(.subheadline)
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackRowCard: View {
  let item: CoachFeedback

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(item.readAt == nil ? Color.MeetPR.brandRed : Color.clear)
        .frame(width: 8, height: 8)
        .padding(.top, 6)
      VStack(alignment: .leading, spacing: 6) {
        Text(item.text)
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(StudentFormatting.dayMonthFormatter.string(from: item.postedAt))
          .font(.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .padding(.top, 2)
    }
    .modifier(DashboardCard())
  }
}
