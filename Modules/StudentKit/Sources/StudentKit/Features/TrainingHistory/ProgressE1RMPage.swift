import CoreModels
import DesignSystem
import SwiftUI

struct ProgressE1RMPage: View {
  let model: ProgressDataModel
  let onOpenToday: () -> Void
  @State private var selection = ProgressE1RMSelection()
  @State private var detail: GrowthE1RMDetail?

  var body: some View {
    ProgressDetailPage(title: StudentStrings.localized(.progressE1rm), model: model) {
      Text(StudentStrings.localized(.trainingHistoryView014))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textFaint)
      HStack(spacing: MeetPRSpacing.point6) {
        ForEach(ProgressE1RMSegment.allCases, id: \.self) { segment in
          StudentSelectionBlock(title: segment.title, isSelected: selection.segment == segment) {
            detail = nil
            selection.segment = segment
          }
        }
      }
      if selection.showsComparison {
        GrowthTotalCard(presentation: model.total(range: selection.range), range: selection.range) {
          selection.cycleRange()
        }
        GrowthComparisonCard(presentation: model.comparison)
      } else if let family = selection.segment.family {
        GrowthE1RMCard(
          snapshot: model.snapshot(family: family, range: selection.range),
          range: selection.range, isGlobalTrainingEmpty: model.stats.trainingSessionCount == 0,
          onOpenToday: onOpenToday, onCycleRange: { selection.cycleRange() },
          onSelectPoint: { detail = model.detail(pointID: $0) }
        )
        .id(family)
      }
    }
    .sheet(item: $detail) { GrowthE1RMDetailSheet(detail: $0) }
  }
}
