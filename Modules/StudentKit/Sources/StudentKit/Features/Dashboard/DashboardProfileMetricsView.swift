import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardProfileMetricsView: View {
  let metrics: DashboardProfileMetrics

  var body: some View {
    if let bodyWeightText = metrics.bodyWeightText,
      let competition = metrics.competition
    {
      HStack(alignment: .top, spacing: MeetPRSpacing.space3) {
        DashboardMetricCard(
          systemImage: "scalemass",
          title: "体重",
          value: bodyWeightText,
          caption: "资料档案"
        )
        DashboardMetricCard(
          systemImage: "flag.checkered",
          title: "距比赛",
          value: "\(competition.days) 天",
          caption: competition.dateText
        )
      }
    } else if let bodyWeightText = metrics.bodyWeightText {
      DashboardMetricCard(
        systemImage: "scalemass",
        title: "体重",
        value: bodyWeightText,
        caption: "资料档案"
      )
    } else if let competition = metrics.competition {
      DashboardMetricCard(
        systemImage: "flag.checkered",
        title: "距比赛",
        value: "\(competition.days) 天",
        caption: competition.dateText
      )
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardMetricCard: View {
  let systemImage: String
  let title: String
  let value: String
  let caption: String

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      HStack(spacing: MeetPRSpacing.space2) {
        Image(systemName: systemImage)
          .foregroundStyle(Color.MeetPR.gold500)
        Text(title)
          .font(.caption)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      Text(value)
        .font(.title3.bold())
        .foregroundStyle(Color.MeetPR.textPrimary)
        .monospacedDigit()
      Text(caption)
        .font(.caption)
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .modifier(DashboardCard())
  }
}
