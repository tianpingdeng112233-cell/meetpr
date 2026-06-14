import DesignSystem
import SwiftUI

/// "评估完成 ✓" summary card (spec 033 §12): excerpts + full-text link;
/// visible only while unread (D7) — opening the full text collapses it. The
/// bottom row tracks the first regular plan (wiki §6.2).
@available(iOS 17.0, macOS 14.0, *)
struct EvaluationCompletedCard: View {
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
