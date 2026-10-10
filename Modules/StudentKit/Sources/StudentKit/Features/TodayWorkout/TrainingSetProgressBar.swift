import DesignSystem
import SwiftUI

struct TrainingSetProgressBar: View {
  let drafts: [TodayWorkoutViewModel.SetRowDraft]
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let segments = TrainingSetProgress.segments(drafts)
    GeometryReader { proxy in
      let total = CGFloat(segments.count) + (segments.contains(.current) ? 0.5 : 0)
      let width = max(
        0, proxy.size.width - CGFloat(max(0, segments.count - 1)) * MeetPRSpacing.point5)
      HStack(spacing: MeetPRSpacing.point5) {
        ForEach(segments.indices, id: \.self) { index in
          TrainingProgressSegment(state: segments[index])
            .frame(width: total > 0 ? width / total * (segments[index] == .current ? 1.5 : 1) : 0)
        }
      }
    }
    .frame(height: MeetPRSpacing.point6)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: segments)
    .accessibilityHidden(true)
  }
}

private struct TrainingProgressSegment: View {
  let state: TrainingSetProgress.Segment

  var body: some View {
    Capsule()
      .fill(fill)
      .overlay {
        if state == .current {
          Capsule().stroke(Color.MeetPR.goldSoft, lineWidth: MeetPRSpacing.point2)
        }
      }
  }

  private var fill: AnyShapeStyle {
    switch state {
    case .complete: AnyShapeStyle(Color.MeetPR.gold500)
    case .failed: AnyShapeStyle(Color.MeetPR.textDisabled)
    case .upcoming: AnyShapeStyle(Color.MeetPR.borderStrong)
    case .current:
      AnyShapeStyle(
        LinearGradient(
          colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.gold400],
          startPoint: .leading, endPoint: .trailing))
    }
  }
}
