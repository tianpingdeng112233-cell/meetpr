import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ProgressDashboardView: View {
  let studentID: UUID
  let plans: any StudentPlanRepository
  let e1rm: any E1RMRepository
  let logs: [StudentSetLog]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        ProgressSectionHeader(title: "e1RM 趋势")
        GrowthCurvePanelView(studentID: studentID, plans: plans, e1rm: e1rm)

        ProgressSectionHeader(title: "容量 / 强度")
        VolumeIntensityChart(buckets: metrics)
      }
      .padding(MeetPRSpacing.md)
    }
    .scrollContentBackground(.hidden)
  }

  private var metrics: [WeeklyProgressMetric] {
    ProgressMetrics.weeklyVolumeIntensity(from: logs)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ProgressSectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(Font.MeetPR.headline)
      .foregroundStyle(Color.MeetPR.fgPrimary)
  }
}
