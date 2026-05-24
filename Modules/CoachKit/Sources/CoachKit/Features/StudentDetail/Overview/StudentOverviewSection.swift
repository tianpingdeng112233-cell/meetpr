import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentOverviewSection: View {
  let summary: StudentOverviewSummary
  let onSelectSection: (StudentDetailSection) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        Button {
          onSelectSection(.execution)
        } label: {
          completionCard
        }
        .buttonStyle(.plain)

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
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
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
        Text("即将上线")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("待 027")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
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
