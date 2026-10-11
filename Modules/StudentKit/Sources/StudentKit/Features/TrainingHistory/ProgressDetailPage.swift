import DesignSystem
import SwiftUI

struct ProgressDetailPage<Content: View>: View {
  let title: String
  let model: ProgressDataModel
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
        if model.isLoaded {
          content()
        } else if model.isFailed {
          ProgressRetryRow { Task { await model.load() } }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity)
        }
      }
      .padding(MeetPRSpacing.pageHorizontal)
    }
    .background(Color.MeetPR.bgBase)
    .navigationTitle(title)
    #if os(iOS)
      .toolbar(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .refreshable { await model.load() }
    .task {
      if !model.isLoaded { await model.load() }
    }
  }
}

struct ProgressIntensityPage: View {
  let model: ProgressDataModel

  var body: some View {
    ProgressDetailPage(title: StudentStrings.localized(.progressIntensity), model: model) {
      VStack(alignment: .leading, spacing: 0) {
        Text(StudentStrings.localized(.trainingHistoryView008))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .padding([.horizontal, .top], MeetPRSpacing.space4)
        VolumeIntensityChart(buckets: model.buckets, isUnlocked: model.stats.unlocksTrends)
      }
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
    }
  }
}
