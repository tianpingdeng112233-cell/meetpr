import DesignSystem
import SwiftUI

/// Design source:
/// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
/// scene 01, feedback-card dashed slot.
@available(iOS 17.0, macOS 14.0, *)
struct DashboardPendingFeedbackCard: View {
  let pending: DashboardPendingFeedbackPresentation
  let coachName: String

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 7) {
        Circle()
          .stroke(Color.MeetPR.gold500, lineWidth: 1.5)
          .frame(width: 7, height: 7)
        Text("教练反馈")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text("· 点评在路上")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
      }

      description
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .lineSpacing(4)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .modifier(DashboardStackedFeedbackCardStyle())
    .accessibilityElement(children: .combine)
  }

  private var description: Text {
    let submitted =
      Text("今天的 ")
      + Text(pending.completedSetCount.formatted()).fontWeight(.semibold)
      + Text(" 组已在 ")
      + Text(pending.submittedAt.formatted(date: .omitted, time: .shortened))
      .fontWeight(.semibold)
    if let expectedResponseHours = pending.expectedResponseHours {
      return
        submitted
        + Text(" 提交，\(coachName)通常 ")
        + Text(expectedResponseHours.formatted()).fontWeight(.semibold)
        + Text(" 小时内回看视频。")
    }
    return submitted + Text(" 提交，\(coachName)会在下次训练前回看视频。")
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardStackedFeedbackCardStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(Color.MeetPR.surfaceCard)
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(Color.MeetPR.gold500)
          .frame(width: 3)
      }
      .clipShape(.rect(cornerRadius: 12))
      .background {
        stackedLayer(
          fill: Color.MeetPR.bgStack,
          horizontalInset: 7,
          verticalOffset: 5
        )
      }
      .background {
        stackedLayer(
          fill: Color.MeetPR.bgInset,
          horizontalInset: 14,
          verticalOffset: 11
        )
      }
      .padding(.bottom, 11)
  }

  private func stackedLayer(
    fill: Color,
    horizontalInset: CGFloat,
    verticalOffset: CGFloat
  ) -> some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(fill)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.surfaceKey, lineWidth: 1)
      }
      .padding(.horizontal, horizontalInset)
      .offset(y: verticalOffset)
  }
}
