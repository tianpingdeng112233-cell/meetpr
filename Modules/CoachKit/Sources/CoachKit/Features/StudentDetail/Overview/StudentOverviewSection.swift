import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentOverviewSection: View {
  let summary: StudentOverviewSummary
  let readiness: ReadinessRowState
  let recentVideos: [StudentVideo]
  let videosUnavailable: Bool
  /// The coach-authored evaluation summary; the 5th card is its permanent
  /// entry after the evaluation banner collapses (spec 033 D5).
  let evaluationSummary: EvaluationSummary?
  let onSelectSection: (StudentDetailSection) -> Void
  let onOpenEvaluationSummary: () -> Void

  init(
    summary: StudentOverviewSummary,
    readiness: ReadinessRowState,
    recentVideos: [StudentVideo],
    videosUnavailable: Bool,
    evaluationSummary: EvaluationSummary? = nil,
    onSelectSection: @escaping (StudentDetailSection) -> Void,
    onOpenEvaluationSummary: @escaping () -> Void = {}
  ) {
    self.summary = summary
    self.readiness = readiness
    self.recentVideos = recentVideos
    self.videosUnavailable = videosUnavailable
    self.evaluationSummary = evaluationSummary
    self.onSelectSection = onSelectSection
    self.onOpenEvaluationSummary = onOpenEvaluationSummary
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        Button {
          onSelectSection(.execution)
        } label: {
          completionCard
        }
        .buttonStyle(.plain)

        StudentReadinessCard(readiness: readiness)

        Button {
          onSelectSection(.feedback)
        } label: {
          feedbackCard
        }
        .buttonStyle(.plain)

        Button {
          onSelectSection(.videos)
        } label: {
          videoCard
        }
        .buttonStyle(.plain)

        Button {
          onOpenEvaluationSummary()
        } label: {
          evaluationSummaryCard
        }
        .buttonStyle(.plain)
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
  }

  private var evaluationSummaryCard: some View {
    Card(accessibilityLabel: "评估总结") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("评估总结")
        if let evaluationSummary {
          Text(evaluationSummary.trainingPlanExcerpt)
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .lineLimit(2)
          Text("更新于 \(CoachStudentFormatting.shortDateText(evaluationSummary.lastUpdatedAt))")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        } else {
          Text("未填写,去写一份")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("评估总结是学员的长期参照")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }

  private var completionCard: some View {
    Card(accessibilityLabel: "本周完成度") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("本周完成度")
        Text("本周完成 \(summary.completedTrainingDays)/\(summary.plannedTrainingDays) 训练日")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        CompletionBar(
          completed: summary.completedTrainingDays,
          total: max(summary.plannedTrainingDays, 1)
        )
        if let latestActivityAt = summary.latestActivityAt {
          Text("上次活跃 \(CoachStudentFormatting.relativeText(latestActivityAt))")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }

  private var feedbackCard: some View {
    Card(accessibilityLabel: "最近反馈") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("最近反馈")
        if let latestFeedback = summary.latestFeedback {
          Text(latestFeedback.text)
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .lineLimit(3)
          Text(CoachStudentFormatting.relativeText(latestFeedback.postedAt))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        } else {
          Text("暂无反馈")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("去反馈段写一条")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }

  private var videoCard: some View {
    Card(accessibilityLabel: "最近视频") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("最近视频")
        if videosUnavailable {
          Text("视频加载失败")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("下拉刷新重试")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        } else if recentVideos.isEmpty {
          Text("学员还没有上传视频")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        } else {
          HStack(spacing: MeetPRSpacing.sm) {
            ForEach(recentVideos) { video in
              VStack(spacing: MeetPRSpacing.xs) {
                Image(systemName: "video.fill")
                  .font(Font.MeetPR.headline)
                  .foregroundStyle(Color.MeetPR.brandRed)
                Text(CoachStudentFormatting.shortDateText(video.displayDate))
                  .font(Font.MeetPR.footnote)
                  .foregroundStyle(Color.MeetPR.fgSecondary)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, MeetPRSpacing.sm)
              .background(Color.MeetPR.surface3)
              .clipShape(.rect(cornerRadius: MeetPRRadius.md))
            }
          }
          Text("查看全部视频")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }
}

/// "今日状态" — the coach's read of today's readiness check-in (spec 030 §C
/// downstream, raw values only; no readiness score per ADR-001).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct StudentReadinessCard: View {
  let readiness: ReadinessRowState

  var body: some View {
    Card(accessibilityLabel: "今日状态") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("今日状态")
        switch readiness {
        case .loaded(let checkin):
          Text(CoachStudentFormatting.readinessScalesText(checkin))
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(CoachStudentFormatting.readinessFatigueText(checkin))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        case .notFiled:
          Text("今日未填")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        case .unavailable:
          Text("暂时无法获取")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("下拉刷新重试")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct CompletionBar: View {
  let completed: Int
  let total: Int

  var body: some View {
    HStack(spacing: MeetPRSpacing.xs) {
      ForEach(0..<total, id: \.self) { index in
        Capsule()
          .fill(index < completed ? Color.MeetPR.green : Color.MeetPR.surface3)
          .frame(height: 8)
      }
    }
  }
}
