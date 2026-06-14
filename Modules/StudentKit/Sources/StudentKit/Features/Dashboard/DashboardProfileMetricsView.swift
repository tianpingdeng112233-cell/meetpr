import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardProfileMetricsView: View {
  let metrics: DashboardProfileMetrics

  var body: some View {
    if let bodyWeightText = metrics.bodyWeightText,
      let competition = metrics.competition
    {
      HStack(alignment: .top, spacing: 12) {
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
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .foregroundStyle(Color.MeetPR.brandRed)
        Text(title)
          .font(.caption)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      Text(value)
        .font(.title3.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .monospacedDigit()
      Text(caption)
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
    .modifier(DashboardCard())
  }
}
