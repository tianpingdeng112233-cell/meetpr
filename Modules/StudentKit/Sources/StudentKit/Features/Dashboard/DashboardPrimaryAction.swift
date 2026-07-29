import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardPrimaryAction: View {
  let liftSubtitle: String
  let canShift: Bool
  let isUpdatingShift: Bool
  let onStart: () -> Void
  let onStartFrameChange: (CGRect) -> Void
  let isStartHidden: Bool
  let onShift: () -> Void

  var body: some View {
    VStack(spacing: 9) {
      GoldCTA(
        "开始训练",
        sub: liftSubtitle,
        variant: .primary,
        icon: .play,
        showsShimmer: true,
        action: onStart
      )
      .onGeometryChange(for: CGRect.self) { proxy in
        proxy.frame(in: .global)
      } action: { frame in
        onStartFrameChange(frame)
      }
      .accessibilityRepresentation {
        Button("开始训练", action: onStart)
      }
      // motion/01 line 90: the source CTA is hidden under the gold ghost.
      .opacity(isStartHidden ? 0 : 1)
      .allowsHitTesting(!isStartHidden)
      .accessibilityHidden(isStartHidden)

      if canShift {
        GoldCTA(
          "顺延一天",
          sub: nil,
          variant: .link,
          icon: .none,
          isDisabled: isUpdatingShift,
          isFullWidth: false,
          action: onShift
        )
      }
    }
    .padding(.top, 2)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardPostponedState: View {
  let tomorrowLabel: String
  let isUpdatingShift: Bool
  let onUndo: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 10) {
        DashboardCheckIcon()
          .stroke(
            Color.MeetPR.success,
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 18, height: 18)
          .padding(.top, 1)

        (Text("本次训练已顺延至 ")
          + Text(tomorrowLabel)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .bold()
          + Text("，之后计划整体后移一天，已通知教练。"))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .lineSpacing(3)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 15)
      .padding(.vertical, 13)
      .background(Color.MeetPR.successRGB.opacity(0.1))
      .clipShape(.rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.MeetPR.successRGB.opacity(0.32), lineWidth: 1)
      }

      Text("今日休息")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textMuted)
        .frame(maxWidth: .infinity)
        .padding(17)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.top, 12)

      Button(action: onUndo) {
        Text("撤销顺延")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textMuted)
          .underline()
          .frame(maxWidth: .infinity, minHeight: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(isUpdatingShift)
    }
  }
}

private struct DashboardCheckIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.width * 0.83, y: rect.height * 0.25))
    path.addLine(to: CGPoint(x: rect.width * 0.375, y: rect.height * 0.71))
    path.addLine(to: CGPoint(x: rect.width * 0.17, y: rect.height * 0.5))
    return path
  }
}
