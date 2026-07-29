import DesignSystem
import SwiftUI

/// Scene 02 visual language for a mature family whose selected window does
/// not contain enough distinct points to draw an honest curve.
@available(iOS 17.0, macOS 14.0, *)
struct GrowthWindowSparseTrendState: View {
  let message: String

  var body: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      GrowthFormingTrendChart(
        recordedCount: 0,
        threshold: GrowthHistoryStats.trendUnlockThreshold,
        currentKg: nil,
        latestRecordDate: nil,
        showsRecordPoints: false
      )
      .frame(height: 68)

      Text(message)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MeetPRSpacing.space3)
        .padding(.vertical, MeetPRSpacing.point9)
        .background(Color.MeetPR.bgInset)
        .clipShape(.rect(cornerRadius: 10))
    }
    .padding(.top, MeetPRSpacing.space2)
    .accessibilityElement(children: .combine)
  }
}
