import DesignSystem
import SwiftUI

struct DashboardOverviewCard: View {
  let overview: DashboardSessionOverview
  let onOpen: (UUID) -> Void

  var body: some View {
    Button {
      onOpen(overview.dayID)
    } label: {
      HStack(spacing: MeetPRSpacing.sm) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: MeetPRSpacing.sm) {
              DashboardOverviewTitle(name: overview.name)
              DashboardOverviewStatus(overview: overview)
            }
            VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
              DashboardOverviewTitle(name: overview.name)
              DashboardOverviewStatus(overview: overview)
            }
          }
          Text(overview.summary)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
          Text(overview.exerciseNames)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right")
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      .padding(MeetPRSpacing.base)
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("dashboard.sessionOverview")
  }

}

private struct DashboardOverviewTitle: View {
  let name: String

  var body: some View {
    Text(name)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
      .foregroundStyle(Color.MeetPR.textPrimary)
  }
}

private struct DashboardOverviewStatus: View {
  let overview: DashboardSessionOverview

  var body: some View {
    Text(overview.statusText)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      .foregroundStyle(overview.status == .current ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
      .padding(.horizontal, MeetPRSpacing.sm)
      .padding(.vertical, MeetPRSpacing.xs)
      .background(
        overview.status == .current ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.bgInset,
        in: .capsule
      )
      .fixedSize(horizontal: false, vertical: true)
  }
}
