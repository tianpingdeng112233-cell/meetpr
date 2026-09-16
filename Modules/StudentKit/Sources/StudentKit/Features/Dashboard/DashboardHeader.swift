import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardHeader: View {
  let weekCode: String
  let statusBadge: String?
  let showsNotifications: Bool
  let unreadCount: Int
  let progressSegments: [DashboardWeekProgressSegment]
  let onOpenNotifications: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack(spacing: 10) {
        MeetPRMark.header
          .frame(width: 97, height: 24, alignment: .leading)
        // Always the real today (sequence-handoff canon: todayStr in all three
        // scenes) — the coach-recommended date lives on the day card only.
        // TimelineView keeps the label rolling over local midnight even when
        // no model state changes to recompute the body.
        TimelineView(.periodic(from: .now, by: 60)) { context in
          Text(DashboardTodayPresentation.headerDateText(context.date, calendar: .current))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .tracking(0.72)
            .foregroundStyle(Color.MeetPR.textMuted)
        }
      }

      HStack(alignment: .top) {
        if let statusBadge {
          HStack(alignment: .bottom, spacing: 11) {
            DashboardEmbossedHeadline(
              text: weekCode,
              foregroundStyle: Color.MeetPR.textDim
            )
            Text(statusBadge)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .bold))
              .foregroundStyle(Color.MeetPR.textMuted)
              .padding(.horizontal, 11)
              .padding(.vertical, 5)
              .background(Color.MeetPR.surfaceElevated, in: .capsule)
              .overlay {
                Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
              }
              .padding(.bottom, 12)
          }
        } else {
          DashboardEmbossedHeadline(
            text: weekCode,
            foregroundStyle: Color.MeetPR.textPrimary
          )
        }

        Spacer(minLength: 8)

        if showsNotifications {
          HeaderChatButton(
            unreadCount: unreadCount,
            accessibilityLabel: StudentStrings.localized(.dashboardHeader001),
            action: onOpenNotifications
          )
        }
      }

      DashboardWeekProgressBar(segments: progressSegments)
        .padding(.top, -8)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardEmbossedHeadline: View {
  let text: String
  let foregroundStyle: Color

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let layers = MeetPRVisualEffects.headlineEmboss(for: colorScheme)
    ZStack {
      ForEach(layers.indices, id: \.self) { index in
        let layer = layers[index]
        headline
          .foregroundStyle(layer.color)
          .blur(radius: layer.swiftUIRadius)
          .offset(x: layer.offsetX, y: layer.offsetY)
          .accessibilityHidden(true)
      }
      headline
        .foregroundStyle(foregroundStyle)
    }
    .fixedSize()
  }

  private var headline: some View {
    Text(text)
      .font(.MeetPR.display(size: MeetPRFontMetrics.size54))
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardWeekProgressBar: View {
  let segments: [DashboardWeekProgressSegment]

  private var displayedSegments: [DashboardWeekProgressSegment] {
    if segments.isEmpty {
      return [
        DashboardWeekProgressSegment(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
          dayNumber: 1,
          recommendedDate: Date(),
          state: .upcoming
        )
      ]
    }
    return segments
  }

  var body: some View {
    GeometryReader { proxy in
      let gap = CGFloat(max(displayedSegments.count - 1, 0)) * 5
      let totalWeight = displayedSegments.reduce(0.0) {
        $0 + ($1.state == .current ? 1.5 : 1)
      }
      let unitWidth = max(0, (proxy.size.width - gap) / totalWeight)

      HStack(spacing: 5) {
        ForEach(displayedSegments) { segment in
          DashboardWeekProgressSegmentView(state: segment.state)
            .frame(width: unitWidth * (segment.state == .current ? 1.5 : 1))
        }
      }
    }
    .frame(height: 4)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardWeekProgressSegmentView: View {
  let state: DashboardWeekProgressState

  var body: some View {
    Capsule()
      .fill(fill)
      .frame(height: 4)
      .shadow(
        color: state == .current
          ? Color.MeetPR.goldRGB.opacity(0.35)
          : .clear,
        radius: state == .current ? 2 : 0
      )
  }

  private var fill: AnyShapeStyle {
    switch state {
    case .done:
      AnyShapeStyle(Color.MeetPR.textPrimary)
    case .current:
      AnyShapeStyle(
        LinearGradient(
          colors: [
            Color.MeetPR.gold500,
            Color.MeetPR.gold400,
            Color.MeetPR.gold300,
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
    case .upcoming:
      AnyShapeStyle(Color.MeetPR.borderStrong)
    }
  }
}
