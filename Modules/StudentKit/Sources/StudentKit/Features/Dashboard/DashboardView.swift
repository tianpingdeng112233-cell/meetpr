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
  private let feedbackViewModel: FeedbackInboxViewModel
  private let evaluationSummaryViewModel: StudentEvaluationSummaryViewModel?
  private let onStartWorkout: () -> Void
  private let onSeeAllFeedback: () -> Void
  @State private var weekViewModel: WeekOverviewViewModel

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedbackViewModel: FeedbackInboxViewModel,
    evaluationSummaryViewModel: StudentEvaluationSummaryViewModel? = nil,
    onStartWorkout: @escaping () -> Void,
    onSeeAllFeedback: @escaping () -> Void
  ) {
    self.studentID = studentID
    self.feedbackViewModel = feedbackViewModel
    self.evaluationSummaryViewModel = evaluationSummaryViewModel
    self.onStartWorkout = onStartWorkout
    self.onSeeAllFeedback = onSeeAllFeedback
    self._weekViewModel = State(initialValue: WeekOverviewViewModel(plans: plans, logs: logs))
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

          DashboardSection(title: "教练反馈", action: ("查看全部", onSeeAllFeedback)) {
            RecentFeedback(viewModel: feedbackViewModel)
          }
        }
        .padding()
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
      .navigationTitle("仪表盘")
    }
    .task {
      if weekViewModel.state == .idle {
        await weekViewModel.load(studentID: studentID)
      }
    }
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
private struct DashboardSection<Content: View>: View {
  let title: String
  var action: (label: String, handler: () -> Void)?
  @ViewBuilder let content: Content

  init(
    title: String,
    action: (label: String, handler: () -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.action = action
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(.title3.bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        if let action {
          Spacer()
          Button(action.label, action: action.handler)
            .font(.subheadline)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
      }
      content
    }
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
    let progress = StudentFormatting.completedCount(for: day, logs: logs)

    VStack(spacing: 6) {
      Text(Self.shortWeekday.string(from: day.date))
        .font(.caption2)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Text(Self.dayNumber.string(from: day.date))
        .font(.headline.monospacedDigit())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Circle()
        .fill(dotColor(progress: progress))
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

  private func dotColor(progress: (completed: Int, total: Int)) -> Color {
    if day.exercises.isEmpty { return Color.MeetPR.fgTertiary.opacity(0.4) }
    if progress.total > 0 && progress.completed == progress.total { return Color.MeetPR.green }
    if progress.completed > 0 { return Color.MeetPR.amber }
    return Color.MeetPR.fgTertiary
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

/// "评估完成 ✓" summary card (spec 033 §12): excerpts + full-text link;
/// visible only while unread (D7) — opening the full text collapses it. The
/// bottom row tracks the first regular plan (wiki §6.2).
@available(iOS 17.0, macOS 14.0, *)
private struct EvaluationCompletedCard: View {
  let viewModel: StudentEvaluationSummaryViewModel

  var body: some View {
    if viewModel.showsDashboardCard, let summary = viewModel.summary {
      VStack(alignment: .leading, spacing: 12) {
        Label("评估完成", systemImage: "checkmark.seal.fill")
          .font(.headline)
          .foregroundStyle(Color.MeetPR.green)

        Text(summary.trainingPlanExcerpt)
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(2)

        if let words = summary.wordsExcerpt {
          Text(words)
            .font(.subheadline)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .lineLimit(2)
        }

        NavigationLink {
          EvaluationSummaryView(summary: summary) {
            viewModel.markRead()
          }
        } label: {
          Text("展开看完整")
            .font(.subheadline)
            .foregroundStyle(Color.MeetPR.brandRed)
        }

        if viewModel.showsAwaitingFirstPlan {
          Text("教练正在为你排第一份正式计划")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      .modifier(DashboardCard())
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardCard: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
  }
}
