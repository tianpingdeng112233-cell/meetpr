#if os(iOS)
  import DesignSystem
  import SwiftUI

  struct VideoTrimTimeline: View {
    private static let handleWidth = MeetPRSpacing.point22
    private static let stripHeight = MeetPRSpacing.point64

    let selection: VideoTrimSelection
    let thumbnails: [VideoTrimThumbnail]
    let onMoveStart: (Double) -> Void
    let onMoveEnd: (Double) -> Void

    var body: some View {
      VStack(spacing: MeetPRSpacing.space2) {
        GeometryReader { geometry in
          let trackWidth = max(1, geometry.size.width - Self.handleWidth)
          let originX = Self.handleWidth / 2
          let startX = originX + trackWidth * selection.startFraction
          let endX = originX + trackWidth * selection.endFraction

          ZStack(alignment: .leading) {
            VideoTrimThumbnailStrip(thumbnails: thumbnails)
              .frame(width: trackWidth, height: Self.stripHeight)
              .offset(x: originX)

            Rectangle()
              .fill(.black.opacity(0.62))
              .frame(width: max(0, startX - originX), height: Self.stripHeight)
              .offset(x: originX)

            Rectangle()
              .fill(.black.opacity(0.62))
              .frame(width: max(0, originX + trackWidth - endX), height: Self.stripHeight)
              .offset(x: endX)

            RoundedRectangle(cornerRadius: MeetPRRadius.sm)
              .stroke(Color.MeetPR.gold500, lineWidth: MeetPRSpacing.point3)
              .frame(width: max(0, endX - startX), height: Self.stripHeight)
              .offset(x: startX)

            VideoTrimHandle(
              edge: .leading,
              currentSeconds: selection.startSeconds,
              secondsPerPoint: selection.sourceDurationSeconds / trackWidth,
              onChange: onMoveStart
            )
            .position(x: startX, y: Self.stripHeight / 2)

            VideoTrimHandle(
              edge: .trailing,
              currentSeconds: selection.endSeconds,
              secondsPerPoint: selection.sourceDurationSeconds / trackWidth,
              onChange: onMoveEnd
            )
            .position(x: endX, y: Self.stripHeight / 2)
          }
        }
        .frame(height: Self.stripHeight)

        HStack {
          VideoTrimTimeLabel(seconds: selection.startSeconds)
          Spacer()
          Text(
            StudentStrings.replacing(
              .videoTrimTimeline001,
              values: ["\(VideoTrimTimeLabel.text(selection.durationSeconds))"])
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.gold500)
          Spacer()
          VideoTrimTimeLabel(seconds: selection.endSeconds)
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(StudentStrings.localized(.videoTrimTimeline002))
    }
  }

  private struct VideoTrimThumbnailStrip: View {
    let thumbnails: [VideoTrimThumbnail]

    var body: some View {
      HStack(spacing: 0) {
        if thumbnails.isEmpty {
          Rectangle()
            .fill(Color.MeetPR.surfaceRaised)
            .overlay {
              Image(systemName: "film")
                .foregroundStyle(Color.MeetPR.textDisabled)
            }
        } else {
          ForEach(thumbnails) { thumbnail in
            Image(uiImage: thumbnail.image)
              .resizable()
              .scaledToFill()
              .frame(maxWidth: .infinity)
              .clipped()
          }
        }
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
    }
  }

  private struct VideoTrimHandle: View {
    enum Edge {
      case leading
      case trailing
    }

    let edge: Edge
    let currentSeconds: Double
    let secondsPerPoint: Double
    let onChange: (Double) -> Void

    @State private var dragOriginSeconds: Double?

    var body: some View {
      ZStack {
        RoundedRectangle(cornerRadius: MeetPRRadius.sm)
          .fill(Color.MeetPR.gold500)
        Capsule()
          .fill(Color.MeetPR.inkOnGold.opacity(0.72))
          .frame(width: MeetPRSpacing.point2, height: MeetPRSpacing.point26)
      }
      .frame(width: MeetPRSpacing.point22, height: MeetPRSpacing.point64)
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let origin = dragOriginSeconds ?? currentSeconds
            if dragOriginSeconds == nil { dragOriginSeconds = currentSeconds }
            onChange(origin + Double(value.translation.width) * secondsPerPoint)
          }
          .onEnded { _ in dragOriginSeconds = nil }
      )
      .accessibilityLabel(
        edge == .leading
          ? StudentStrings.localized(.videoTrimTimeline003)
          : StudentStrings.localized(.videoTrimTimeline004)
      )
      .accessibilityValue(VideoTrimTimeLabel.text(currentSeconds))
      .accessibilityAdjustableAction { direction in
        let step = 1.0
        switch direction {
        case .increment: onChange(currentSeconds + step)
        case .decrement: onChange(currentSeconds - step)
        @unknown default: break
        }
      }
    }
  }

  private struct VideoTrimTimeLabel: View {
    let seconds: Double

    var body: some View {
      Text(Self.text(seconds))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textTertiary)
        .monospacedDigit()
    }

    static func text(_ seconds: Double) -> String {
      Duration.seconds(Int(max(0, seconds).rounded()))
        .formatted(.time(pattern: .minuteSecond))
    }
  }

  extension VideoTrimSelection {
    fileprivate var startFraction: Double {
      guard sourceDurationSeconds > 0 else { return 0 }
      return startSeconds / sourceDurationSeconds
    }

    fileprivate var endFraction: Double {
      guard sourceDurationSeconds > 0 else { return 0 }
      return endSeconds / sourceDurationSeconds
    }
  }
#endif
